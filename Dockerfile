FROM node:12-buster
LABEL maintainer="KnowledgeVis, LLC <curtislisle@knowledgevis.com>"

# Dockerfile to build Arbor-Nova self-contained container.  Start with a basic girder instance
# by using startup sequence from Kitware's 
EXPOSE 8080

RUN mkdir /girder

RUN apt-get update && apt-get install -qy \
	apt-utils \
    gcc \
    libpython3-dev \
    git \
    libldap2-dev \
    libsasl2-dev  && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

RUN alias python="python3"

# get pip3 for installations
RUN wget https://bootstrap.pypa.io/get-pip.py && python3 get-pip.py

# download girder source code
RUN git clone https://github.com/girder/girder.git  /girder

WORKDIR /girder

# See http://click.pocoo.org/5/python3/#python-3-surrogate-handling for more detail on
# why this is necessary.
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# TODO: Do we want to create editable installs of plugins as well?  We
# will need a plugin only requirements file for this.
RUN pip install --upgrade --upgrade-strategy eager --editable .
RUN pip install girder-worker[girder]
RUN girder build

# install mongoDB
RUN apt-get install gnupg
RUN wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc |  apt-key add -
RUN echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.2 main" | tee /etc/apt/sources.list.d/mongodb-org-4.2.list
RUN apt-get update
RUN apt-get install -y mongodb-org

# go to the configuration directory and change the defaults so the website will be visible outside the container
WORKDIR /girder/girder/conf
RUN sed -i -r "s/127.0.0.1/0.0.0.0/" girder.dist.cfg

#----- after girder install
# download girder worker
RUN echo 'installing girder_worker'
WORKDIR /
RUN git clone http://github.com/girder/girder_worker /girder_worker
WORKDIR /girder_worker
#RUN git fetch --all --tags --prune
RUN git checkout 7a590f6f67230e2f98e8acecd313f00d76bdbf00
RUN pip install -e .[girder_io]

# get rabbitmq
RUN apt-get update
RUN apt-get install -qy --fix-missing rabbitmq-server

RUN pip install .[girder_io,worker]

# --- install R since it is used by arbor_nova
RUN apt-get install -qy r-base
RUN apt-get install -qy r-base-core

# ----- get arbor_nova
RUN echo 'installing arbor_nova plugin'
#RUN pip install ansible
WORKDIR /
RUN git clone http://github.com/arborworkflows/arbor_nova
WORKDIR /arbor_nova
RUN git checkout rhabdo_on_aws

# override the default girder webpage
WORKDIR /arbor_nova/girder_plugin
RUN pip install -e .

# install the girder_worker jobs
WORKDIR /arbor_nova/girder_worker_tasks
RUN pip install -e .

# --- install the UI
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update &&  apt-get install -qy yarn
WORKDIR /arbor_nova/client
RUN yarn global add @vue/cli
RUN yarn install
RUN yarn build
# gave up on this build time copy because we couldn't reference the dist dir.  the copy has been moved to startup.sh
#COPY ./dist /arbornova

# -- install dependencies for Deep Learning scripts
RUN pip install torch
RUN pip install torchvision
RUN pip install opencv-python
RUN pip install albumentations
RUN pip install scikit-image
RUN pip install segmentation_models_pytorch
RUN pip install tensorflow
RUN pip install keras

WORKDIR /
# copy init script(s) over and start all jobs
COPY . .

ENTRYPOINT ["sh", "startup.sh"]



FROM nvidia/cuda:10.0-base

LABEL maintainer="KnowledgeVis, LLC <curtislisle@knowledgevis.com>"

# Dockerfile to build Arbor-Nova self-contained container.  Start with a basic girder instance
# by using startup sequence from Kitware's 
EXPOSE 8080

RUN mkdir /girder

# install supporting libraries.  Also install virtualenv so we can create different 
# runtime dependency sets. libtiff-dev is included to fix a bug in the native TIFF
# library bundled with ubuntu (so large_image works better).

RUN apt-get update && apt-get install -qy \
	apt-utils \
    gcc \
    libpython3-dev \
    git \
    libldap2-dev \
    libtiff-dev  \
    libsasl2-dev  && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

RUN alias python="python3"


RUN apt-get update
# wget is used for pulling a pre-trained model
RUN apt-get install -qy wget 

# get pip3 for installations
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN apt-get install -qy python3 
RUN apt-get install -qy python3-distutils
RUN python3 get-pip.py

# download nodejs for web UI
RUN apt-get install -qy curl
RUN curl  -sL https://deb.nodesource.com/setup_12.x | bash
RUN apt-get install -qy nodejs

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

# set time zone for mongodb
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install tzdata
# might want to fix the timezone later by setting tz and running this?
#RUN dpkg-reconfigure --frontend noninteractive tzdata

# needed to add this after 10/2019 due to change in mongodb setup.  It tries to run systemctl
# which isn't installed in docker containers
# see description here: https://stackoverflow.com/questions/63709096/systemctl-not-found-while-building-mongo-image/64949118#64949118
RUN ln -s /bin/true /usr/local/bin/systemctl

# install mongoDB
RUN apt-get install -y gnupg
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

# -- install dependencies for Deep Learning scripts. Important to pin the 
# versions of torch and torchvision, otherwise torch=>=1.6.0 is downloaded, 
# and torch=1.6.0 requires too new an nvidia driver.  This is used to support the
# girder_worker based apps (segmentation and MYOD1 mutation)

RUN pip install torch==1.4.0
RUN pip install torchvision==0.5.0
RUN pip install efficientnet-pytorch==0.6.3
RUN pip install opencv-python
RUN pip install albumentations
RUN pip install scikit-image
RUN pip install segmentation_models_pytorch==0.1.0 --no-dependencies
RUN pip install timm==0.1.18  --no-dependencies
RUN pip install torchnet
# install large_image for reading image formats the find-links helps this run fast
RUN pip install large_image[sources] --find-links https://girder.github.io/large_image_wheels 
RUN pip install pretrainedmodels

# We need a different dependency stack to run the survivability, since it uses timm=0.3.2. 
# so create a virtualenv and install the alternative dependencies there.  When the survivability
# app is run, it is run via shell that uses this environment instead of the "standard" environment
# used above for the rest of the applications. 

RUN pip install virtualenv
WORKDIR /
RUN virtualenv rms_venv

ENV OLDPATH=$PATH
ENV PATH="/rms_venv/bin:$PATH" 
RUN pip install girder_client
RUN pip install opencv-python
# newer torch versions had errors with the models
RUN pip install torch==1.7.1  
RUN pip install scikit-image
RUN pip install albumentations
# (it wanted to install torch=1.8.1)
RUN pip install segmentation_models_pytorch==0.1.3 --no-dependencies 
RUN pip install pretrainedmodels
RUN pip install torchvision==0.8.2 --no-dependencies
RUN pip install efficientnet-pytorch==0.6.3
RUN pip install timm==0.3.2 --no-dependencies
RUN pip install openslide-python

# now we are done building the survivability environment, lets go back
# to the standard path for everything else.  girder and girder_worker 
# use the standard path.  It is only the remote part of the survivability
# job that uses the alternative environment.  The remote job will invoke
# this virtual environment when it runs. 

ENV PATH="$OLDPATH"

# ----- get web app framework (derived from github.com/arborworkfows/arbor_nova)
RUN echo 'installing rms_infer_web plugin'
#RUN pip install ansible
WORKDIR /
RUN git clone http://github.com/knowledgevis/rms_infer_web
WORKDIR /rms_infer_web
RUN git checkout arbor_survivability

# override the default girder webpage
WORKDIR /rms_infer_web/girder_plugin
RUN pip install -e .

# install the girder_worker jobs
WORKDIR /rms_infer_web/girder_worker_tasks
RUN pip install -e .

# --- install the UI
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update &&  apt-get install -qy yarn
WORKDIR /rms_infer_web/client
RUN yarn global add @vue/cli
RUN yarn install
RUN yarn build

# now install girder_client, so the startup shell can add an assetstore automatically for girder
RUN pip install girder_client

# these are things missing from the standard environment
RUN pip install pandas
RUN pip install matplotlib
RUN pip install arrow

# Note about weights for trained networks:  It is the convention to place any trained network weights files 
# in the /rms_infer_web/models directory.  These weights files are not included in the github repository 
# because of their size. The copy below will copy all files in the development directory, 
# so weights files will automatically be included in the container. Any software that references weights 
# can assume their files for restoration will be in the "/rms_infer_web/models directory.

# To build the container again, the user will need to separately aquire and load model weights 
# into the proper directory before building the container. 

WORKDIR /
# copy init script(s) over and start all jobs
COPY . .

# pull a pretrained model
#RUN echo "Downloading a pre-trained segmentation model for RMS detection. This may take a few minutes"
#WORKDIR /rms_infer_web/models
#RUN wget https://data.kitware.com/api/v1/item/60f768922fa25629b9c6940b/download

# finish the setup.  This has to initialize the girder subsystem used for data management 
ENTRYPOINT ["sh", "startup.sh"]


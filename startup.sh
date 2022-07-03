#!/bin/sh

# copy files over because we couldn't copy during the docker build process 
#cp -r /rms_infer_web/client/dist /usr/share/girder/static/arbornova
cp -r /rms_infer_web/client/dist /original_venv/share/girder/static/arbornova

# copy over images for open sea dragon's pretty buttons
#cp -r images /usr/share/girder/static/arbornova
cp -r images /original_venv/share/girder/static/arbornova

# copy over any model weights to the destination directory. The weights are read during model execution.
cp -r models rms_infer_web/models

# copy over cohort data files used for visualization to the destination directory. 
cp -r data rms_infer_web/data

# run mongo
nohup  mongod --config /etc/mongod.conf &
girder serve &

# the communication between jobs and girder
rabbitmq-server &

# wait for girder to come up and then add an assetstore. An assetstore is needed to handle uploads
# rather then 10 secs, we could do a wait until curl localhost:8080 is available
sleep 10 
python3 girder_assetstore.py

# push sample images into girder for use in the apps
sleep 15
python3 girder_sample_images.py


# force girder worker to run as root because we don't have other users
cd /rms_infer_web

export C_FORCE_ROOT=True
python3 -m girder_worker --concurrency=1 --max-tasks-per-child=1


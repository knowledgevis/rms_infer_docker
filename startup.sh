#!/bin/sh

# copy files over because we couldn't copy during the docker build process 
cp -r /arbor_nova/client/dist /usr/share/girder/static/arbornova

# run mongo
nohup  mongod --config /etc/mongod.conf &
girder serve &

# the communication between jobs and girder
rabbitmq-server &

# wait for girder to come up and then add an assetstore. An assetstore is needed to handle uploads
sleep 5
python3 girder_assetstore.py

# force girder worker to run as root because we don't have other users
export C_FORCE_ROOT=True
/usr/bin/python3 -m girder_worker 


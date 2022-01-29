# rms_infer_docker
This repository is a Dockerfile used to build a web-based rhabdomyosarcoma (RMS) H&E slide analysis system.  A web interface supports several applications that provide RMS segmentation of whole slide images, MYOD mutation analysis, and survivability risk stratification applications. 

This repository sets up the dependencies and builds in a startup script to initialize the container when it starts. 


The main contribution of this Dockerfile is the all-in-one nature of the build.  Multiple services (mongo, girder, girder-worker, rabbitmq, Node.js, CUDA, etc.) are all build in this container.   Therefore, a user only needs NVIDIA drivers installed on their system in order to run this deep 
learning application. 

Notes:
This builds on a CUDA-10 base image in order to have accelerated deep learning included. It has been tested using PyTorch and Keras-based applications. 
To do:
Before production deployment, tests should be added for dropped services.  No such testing is currently incuded, so applications using this 
container may fail during runtime if any of the services in the container experience a run-time failure. 

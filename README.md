# arbor_nova_docker_fnlcr
This repository is a Dockerfile used to build a version of Girder, complete with Girder-worker, that contains a built-in mini application framework.
This dockerfile checks out the application (from the arbor_nova repository) during the course of its building process.  

The main contribution of this Dockerfile is the all-in-one nature of the build.  Multiple services (mongo, girder, girder-worker, rabbitmq, 
Node.js, CUDA) are all build in this container.   Therefore, a user only needs NVIDIA drivers installed on their system in order to run deep 
learning applications. 

Notes:
This builds on a CUDA-10 base image in order to have accelerated deep learning included. It has been tested using PyTorch and Keras-based applications. 
To do:
Before production deployment, tests should be added for dropped services.  No such testing is currently incuded, so applications using this 
container may fail during runtime if any of the services in the container experience a run-time failure. 

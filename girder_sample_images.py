# girder_sample_images.py

# These routines are called after the Girder storage system is running.  The purpose 
# is to upload sample images into the girder instance so they can be found during
# use of the system. 

import girder_client

import os
from  dotenv import load_dotenv

# fetch the user identity set in a .env file when the container is built.
# use this identify to log into girder and create an assetstore
load_dotenv()
ANON_USER = os.getenv('ANONYMOUS_USER')
ANON_PASS = os.getenv('ANONYMOUS_PASSWORD')

collName = 'sampleImages'
folderName = 'sampleImages'
itemName = 'images'


def uploadImage(filepath,item_name):

    print('Sample Images: trying to login with credentials:',ANON_USER,ANON_PASS)
    # login to girder system in order to upload
    gc = girder_client.GirderClient(apiUrl='http://localhost:8080/girder/api/v1')
    login = gc.authenticate(ANON_USER, ANON_PASS)

    # find or create collection
    try:
        record = gc.resourceLookup('/collection/'+collName)
        collID = record['_id']
    except girder_client.HttpError:
        # didn't find the collection, so create it
        print('creating collection',collName)
        newcollinfo = gc.createCollection(collName,description='',public=False)
        collID = newcollinfo['_id']   # check if the folder exists in Arbor, and create it if necessary

    # now create the folder inside the collection if necessary
    try:
        record = gc.resourceLookup('/collection/'+collName+'/'+folderName)
        folderID = record['_id']
    except girder_client.HttpError:
        # didn't find the folder, so create it
        print('creating folder ',folderName)
        newfolderinfo = gc.createFolder(collID,folderName,description='',parentType='collection',public=False)
        folderID = newfolderinfo['_id']

    # if necessary, create the item and attach the file to the item
    try:
        record = gc.resourceLookup('/collection/'+collName+'/'+folderName+'/'+itemName)
        itemID = record['_id']
    except:
        print('creating item ',itemName)
        item = gc.createItem(folderID, 'samples', 'sample images for use as demonstrations')
        itemID = item['_id']

    # add this file to the item in girder
    # uploadFileToItem(item,'sample.txt','sample')
    status = gc.uploadFileToItem(itemID, filepath,filename=item_name)
    return status

# upload any images needed for demos
print('uploading sample images')
status = uploadImage('sample_images/Sample_WSI_Image.svs','Sample_WSI_Image.svs')
status = uploadImage('sample_images/Sample_WSI_Segmentation.png','Sample_WSI_Segmentation.png')
print('status:',status)

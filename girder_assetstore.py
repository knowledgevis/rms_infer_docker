import girder_client
gc = girder_client.GirderClient(apiUrl='http://localhost:8080/girder/api/v1')
login = gc.authenticate('anonymous', 'letmein')
newasset = gc.sendRestRequest('POST','assetstore',{'name':'assets','type': 0,'root':'/assets'})
print(newasset)
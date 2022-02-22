import girder_client
import os
from  dotenv import load_dotenv

load_dotenv()
ANON_USER = os.getenv('ANONYMOUS_USER')
ANON_PASS = os.getenv('ANONYMOUS_PASSWORD')

gc = girder_client.GirderClient(apiUrl='http://localhost:8080/girder/api/v1')
login = gc.authenticate(ANON_USER, ANON_PASS)
newasset = gc.sendRestRequest('POST','assetstore',{'name':'assets','type': 0,'root':'/assets'})
print(newasset)
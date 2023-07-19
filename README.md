# Valheim Server Deployment in Azure Container Instances

Deploy an API hosted in an Azure FunctionApp that when triggered, will create a Valheim Server in Azure Container Instances

## How to deploy

Build the docker image from https://github.com/lloesche/valheim-server-docker and push to a container registry. The provided templates assume you are using Azure Container Registry. You can deploy an Azure Container Registry and build the docker from the Azure CLI also
```bash
az acr build -r <RegistryName> https://github.com/lloesche/valheim-server-docker -f DOCKERFILE --platform linux
```

Use the Azure CLI or Azure Powershell to deploy the main.bicep template
```bash
az deployment sub create -n <deploymentName> --template-file main.bicep
```

Store your server password in a new secret in the Azure Keyvault that is created by the deployment
```bash
az keyvault secret set -n <secretName> --vault-name <keyVault Name> --value <yourSuperSecretPassword>
```
Once the Function, Hosting Plan, Storage, etc have been deployed by the template, you need to deploy the FunctionApp code. 
Change into the Function dir and run
```bash
az functionapp deploy --name AppName --resource-group ResouceGroup --src-path ./
```

## How to run

Once the deployment has run, you can log into the Azure Portal and get the FunctionApp URL and use that to call the API to build your game server using a POST method and the following JSON schema:
```
{"action":"start/stop","region":"azureRegsion","servername":"myvhserver","worldname":"myworldname","customerId":"nameOfKeyvaultSecret"}
```
Use the FunctionApp URL to call the API in Postman or CURL or whatever.  When specifying a region in the request, make sure that's the region your storage is deployed to, or you're going to have a bad time.
Example using CURL:
```bash
URL=<url to api endpoint with apikey>
ACTION= "start"
REGION=<azure region>
SERVERNAME="myservername"
WORLDNAME="myworldname"
SECRETNAME="name of the keyvualt secret"
DATA={"\action"\:"\$ACTION"\,"\region"\:"\$REGION"\,"\servername"\:"\$SERVERNAME"\,"\WORLDNAME"\:"\$WORLDNAME"\,"\customerId"\:"\$SECRETNAME"\}

curl -X POST -d $DATA $URL
```
To stop, and delete the Container Instance, just need to send in request with the value "stop" in the action key

```bash
URL=<url to api endpoint with apikey>
ACTION="stop"
DATA={"\action"\:"\$ACTION"\}
```
Your game data will be saved on the Azure Storage Files shares set up by the templates. 

Happy tree chopping!
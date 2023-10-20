param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param env array
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'webadmin'
param exists bool

param storageAccountName string 
param formRecognizerName string 
param ContentSafetyName string 
param AzureCognitiveSearch string 
param openAiName string

resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

module app '../core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityType: 'UserAssigned'
    identityName: identityName
    exists: exists
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    env: env
    targetPort: 80
    AzureCognitiveSearch:AzureCognitiveSearch
    ContentSafetyName:ContentSafetyName
    formRecognizerName:formRecognizerName
    storageAccountName:storageAccountName
    openAiName:openAiName
  }
}


output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = webIdentity.properties.principalId
output SERVICE_WEBADMIN_NAME string = app.outputs.name
output SERVICE_WEBADMIN_URI string = app.outputs.uri
output SERVICE_WEBADMIN_IMAGE_NAME string = app.outputs.imageName

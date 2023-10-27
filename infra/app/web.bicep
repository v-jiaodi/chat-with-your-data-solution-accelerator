param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param env array
// param applicationInsightsName string
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'web'
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

// resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
//   name: applicationInsightsName
// }

output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = webIdentity.properties.principalId
output SERVICE_WEB_NAME string = app.outputs.name
output SERVICE_WEB_URI string = app.outputs.uri
output SERVICE_WEB_IMAGE_NAME string = app.outputs.imageName
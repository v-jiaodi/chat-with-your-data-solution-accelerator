targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param appServicePlanName string = ''
// param backendServiceName string = ''
// param frontendServiceName string = ''
param resourceGroupName string = ''
param AzureOpenAIApiVersion string = '2023-07-01-preview'
// param WebAppImageName string = 'DOCKER|fruoccopublic.azurecr.io/rag-webapp'
// param AdminWebAppImageName string = 'DOCKER|fruoccopublic.azurecr.io/rag-adminwebapp'
// param BackendImageName string = 'DOCKER|fruoccopublic.azurecr.io/rag-backend'
// param AzureOpenAIModel string = 'gpt-35-turbo'
// param AzureOpenAIEmbeddingModel string = 'text-embedding-ada-002'

param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''
param logAnalyticsName string = ''
param keyVaultName string = ''
param webAdminAppExists bool = false
param webAdminContainerAppName string = ''

param applicationInsightsName string = ''
param eventgridName string = 'doc-processing'
param QueueName string = 'doc-processing'
param BlobContainerName string = 'documents'
param functionAppName string = ''
param searchServiceName string = ''
param searchServiceResourceGroupName string = ''
param searchServiceLocation string = ''
// The free tier does not support managed identity (required) or semantic search (optional)
@allowed(['basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchServiceSkuName string // Set in main.parameters.json
param searchIndexName string  = '${environmentName}-index'// Set in main.parameters.json
// param searchQueryLanguage string // Set in main.parameters.json
// param searchQuerySpeller string // Set in main.parameters.json

param storageAccountName string = ''
param storageResourceGroupName string = ''
param storageResourceGroupLocation string = location
param storageContainerName string = 'content'
param storageSkuName string // Set in main.parameters.json

@allowed(['azure', 'openai'])
param openAiHost string // Set in main.parameters.json

param openAiServiceName string = ''
param openAiResourceGroupName string = ''
@description('Location for the OpenAI resource group')
@allowed(['canadaeast', 'eastus', 'eastus2', 'francecentral', 'switzerlandnorth', 'uksouth', 'japaneast', 'northcentralus'])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiResourceGroupLocation string

param openAiSkuName string = 'S0'

param openAiApiKey string = ''
param openAiApiOrganization string = ''

param formRecognizerServiceName string = ''
param formRecognizerResourceGroupName string = ''
param formRecognizerResourceGroupLocation string = location

param contentsafetyResourceGroupName string = ''
param contentsafetyServiceName string = ''
// param fcontentSafetyResourceGroupLocation string = location

param formRecognizerSkuName string = 'S0'

param chatGptDeploymentName string // Set in main.parameters.json
param chatGptDeploymentCapacity int = 30
param chatGptModelName string = (openAiHost == 'azure') ? 'gpt-35-turbo' : 'gpt-3.5-turbo'
param chatGptModelVersion string = '0613'
param embeddingDeploymentName string // Set in main.parameters.json
param embeddingDeploymentCapacity int = 30
param embeddingModelName string = 'text-embedding-ada-002'

// Used for the optional login and document level access control system
// param useAuthentication bool = false
// param serverAppId string = ''
@secure()
// param serverAppSecret string = ''
// param clientAppId string = ''

// Used for optional CORS support for alternate frontends
// param allowedOrigin string = '' // should start with https://, shouldn't end with a /

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Use Application Insights for monitoring and performance tracing')
// param useApplicationInsights bool = true

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

resource contentsafetyResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(contentsafetyResourceGroupName)) {
  name: !empty(contentsafetyResourceGroupName) ? contentsafetyResourceGroupName : resourceGroup.name
}

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(openAiResourceGroupName)) {
  name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : resourceGroup.name
}

resource formRecognizerResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(formRecognizerResourceGroupName)) {
  name: !empty(formRecognizerResourceGroupName) ? formRecognizerResourceGroupName : resourceGroup.name
}

resource searchServiceResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(searchServiceResourceGroupName)) {
  name: !empty(searchServiceResourceGroupName) ? searchServiceResourceGroupName : resourceGroup.name
}

resource storageResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (!empty(storageResourceGroupName)) {
  name: !empty(storageResourceGroupName) ? storageResourceGroupName : resourceGroup.name
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B3'
      capacity: 1
    }
    kind: 'linux'
  }
}

// The webAdmin 
// module backend 'core/host/appservice.bicep' = {
//   name: 'api'
//   scope: resourceGroup
//   params: {
//     name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'
//     location: location
//     tags: union(tags, { 'azd-service-name': 'backend' })
//     appServicePlanId: appServicePlan.outputs.id
//     runtimeName: 'python'
//     // linuxFxVersion:AdminWebAppImageName
//     runtimeVersion: '3.11'
//     appCommandLine: 'python3 -m gunicorn main:app'
//     scmDoBuildDuringDeployment: true
//     managedIdentity: true
//     allowedOrigins: [allowedOrigin]
//     AzureCognitiveSearch:searchService.outputs.name
//     formRecognizerName:formRecognizer.outputs.name
//     ContentSafetyName:contentSafety.outputs.name
//     storageAccountName:storage.outputs.name
//     appSettings: {
//       AZURE_STORAGE_ACCOUNT: storage.outputs.name
//       AZURE_STORAGE_CONTAINER: storageContainerName
//       AZURE_SEARCH_INDEX: searchIndexName
//       AZURE_SEARCH_USE_SEMANTIC_SEARCH : 'false'
//       AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG : 'default'
//       AZURE_SEARCH_INDEX_IS_PRECHUNKED : 'false'
//       AZURE_SEARCH_TOP_K : '5'
//       AZURE_SEARCH_ENABLE_IN_DOMAIN : 'false'
//       AZURE_SEARCH_CONTENT_COLUMNS : 'content'
//       AZURE_SEARCH_FILENAME_COLUMN : 'filename'
//       AZURE_SEARCH_TITLE_COLUMN : 'title'
//       AZURE_SEARCH_URL_COLUMN : 'url'
//       AZURE_OPENAI_RESOURCE : openAiHost == 'azure' ? openAi.outputs.name : ''
//       AZURE_OPENAI_KEY : openAiApiKey
//       AZURE_OPENAI_MODEL : chatGptModelName
//       AZURE_OPENAI_MODEL_NAME : chatGptModelName
//       AZURE_OPENAI_TEMPERATURE : '0'
//       AZURE_OPENAI_TOP_P: '1'
//       AZURE_OPENAI_MAX_TOKENS : '1000'
//       AZURE_OPENAI_STOP_SEQUENCE : '\n'
//       AZURE_OPENAI_SYSTEM_MESSAGE : 'You are an AI assistant that helps people find information.'
//       AZURE_OPENAI_API_VERSION : '2023-07-01-preview'
//       AZURE_OPENAI_STREAM : 'true'
//       AZURE_OPENAI_EMBEDDING_MODEL : embeddingDeploymentName
//       AZURE_FORM_RECOGNIZER_ENDPOINT : 'https://${location}.api.cognitive.microsoft.com/'
//       // AZURE_FORM_RECOGNIZER_KEY : listKeys('Microsoft.CognitiveServices/accounts/${formRecognizer.name}', '2023-05-01').key1
//       AZURE_BLOB_ACCOUNT_NAME : storageAccountName
//       // AZURE_BLOB_ACCOUNT_KEY : listKeys('Microsoft.Storages/accounts/${storageAccountName}', '2023-05-01').keys[0].value
//       AZURE_BLOB_CONTAINER_NAME : 'documents'
//       ORCHESTRATION_STRATEGY : 'langchain'
//       AZURE_CONTENT_SAFETY_ENDPOINT: contentsafetyServiceName
//       // AZURE_CONTENT_SAFETY_KEY : listKeys('Microsoft.CognitiveServices/accounts/${ContentSafety.name}', '2023-05-01').key1
//       AZURE_SEARCH_SERVICE: searchService.outputs.name
//       AZURE_SEARCH_QUERY_LANGUAGE: searchQueryLanguage
//       AZURE_SEARCH_QUERY_SPELLER: searchQuerySpeller
//       APPLICATIONINSIGHTS_CONNECTION_STRING: useApplicationInsights ? monitoring.outputs.applicationInsightsConnectionString : ''
//       // Shared by all OpenAI deployments
//       OPENAI_HOST: openAiHost
//       AZURE_OPENAI_EMB_MODEL_NAME: embeddingModelName
//       AZURE_OPENAI_CHATGPT_MODEL: chatGptModelName
//       // Specific to Azure OpenAI
//       AZURE_OPENAI_SERVICE: openAiHost == 'azure' ? openAi.outputs.name : ''
//       AZURE_OPENAI_CHATGPT_DEPLOYMENT: chatGptDeploymentName
//       AZURE_OPENAI_EMB_DEPLOYMENT: embeddingDeploymentName
//       // Used only with non-Azure OpenAI deployments
//       OPENAI_API_KEY: openAiApiKey
//       OPENAI_ORGANIZATION: openAiApiOrganization
//       // Optional login and document level access control system
//       AZURE_USE_AUTHENTICATION: useAuthentication
//       AZURE_SERVER_APP_ID: serverAppId
//       AZURE_SERVER_APP_SECRET: serverAppSecret
//       AZURE_CLIENT_APP_ID: clientAppId
//       AZURE_TENANT_ID: tenant().tenantId
//       // CORS support, for frontends on other hosts
//       ALLOWED_ORIGIN: allowedOrigin
//     }
//   }
//   dependsOn:[
//     formRecognizer
//   ]
// }

// The web frontend
// module frontend 'core/host/appservice.bicep' = {
//   name: '${environmentName}-website'
//   scope: resourceGroup
//   params: {
//     name: !empty(frontendServiceName) ? frontendServiceName : '${abbrs.webSitesAppService}frontend-${resourceToken}'
//     location: location
//     tags: union(tags, { 'azd-service-name': 'frontend' })
//     appServicePlanId: appServicePlan.outputs.id
//     runtimeName: 'node'
//     runtimeVersion: '18-lts'
//     // linuxFxVersion:WebAppImageName
//     scmDoBuildDuringDeployment: true
//     managedIdentity: true
//     allowedOrigins: [allowedOrigin]
//     AzureCognitiveSearch:searchService.outputs.name
//     formRecognizerName:formRecognizer.outputs.name
//     ContentSafetyName:contentSafety.outputs.name
//     storageAccountName:storage.outputs.name
//     openAiName:openAi.outputs.name
//     appSettings: {
//       APPINSIGHTS_CONNECTION_STRING: monitoring.outputs.applicationInsightsConnectionString
//       AZURE_STORAGE_ACCOUNT: storage.outputs.name
//       AZURE_STORAGE_CONTAINER: storageContainerName
//       AZURE_SEARCH_INDEX: searchIndexName
//       AZURE_SEARCH_CONVERSATIONS_LOG_INDEX: 'conversations'
//       AZURE_SEARCH_USE_SEMANTIC_SEARCH : 'false'
//       AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG : 'default'
//       AZURE_SEARCH_INDEX_IS_PRECHUNKED : 'false'
//       AZURE_SEARCH_TOP_K : '5'
//       AZURE_SEARCH_ENABLE_IN_DOMAIN : 'false'
//       AZURE_SEARCH_CONTENT_COLUMNS : 'content'
//       AZURE_SEARCH_FILENAME_COLUMN : 'filename'
//       AZURE_SEARCH_TITLE_COLUMN : 'title'
//       AZURE_SEARCH_URL_COLUMN : 'url'
//       AZURE_OPENAI_RESOURCE : openAiHost == 'azure' ? openAi.outputs.name : ''
//       AZURE_OPENAI_KEY : openAiApiKey
//       AZURE_OPENAI_MODEL : chatGptModelName
//       AZURE_OPENAI_MODEL_NAME : chatGptModelName
//       AZURE_OPENAI_TEMPERATURE : '0'
//       AZURE_OPENAI_TOP_P: '1'
//       AZURE_OPENAI_MAX_TOKENS : '1000'
//       AZURE_OPENAI_STOP_SEQUENCE : '\n'
//       AZURE_OPENAI_SYSTEM_MESSAGE : 'You are an AI assistant that helps people find information.'
//       AZURE_OPENAI_API_VERSION : '2023-07-01-preview'
//       AZURE_OPENAI_STREAM : 'true'
//       AZURE_OPENAI_EMBEDDING_MODEL : embeddingDeploymentName
//       AZURE_FORM_RECOGNIZER_ENDPOINT : 'https://${location}.api.cognitive.microsoft.com/'
//       // AZURE_FORM_RECOGNIZER_KEY : listKeys('Microsoft.CognitiveServices/accounts/${formRecognizer.name}', '2023-05-01').key1
//       AZURE_BLOB_ACCOUNT_NAME : storage.outputs.name
//       // AZURE_BLOB_ACCOUNT_KEY : listKeys('Microsoft.Storages/accounts/${storageAccountName}', '2023-05-01').keys[0].value
//       AZURE_BLOB_CONTAINER_NAME : 'documents'
//       ORCHESTRATION_STRATEGY : 'langchain'
//       AZURE_CONTENT_SAFETY_ENDPOINT: contentsafetyServiceName
//       // AZURE_CONTENT_SAFETY_KEY : listKeys('Microsoft.CognitiveServices/accounts/${ContentSafety.name}', '2023-05-01').key1
//       AZURE_SEARCH_SERVICE: searchService.outputs.name
//       AZURE_SEARCH_QUERY_LANGUAGE: searchQueryLanguage
//       AZURE_SEARCH_QUERY_SPELLER: searchQuerySpeller
//       APPLICATIONINSIGHTS_CONNECTION_STRING: useApplicationInsights ? monitoring.outputs.applicationInsightsConnectionString : ''
//       // Shared by all OpenAI deployments
//       OPENAI_HOST: openAiHost
//       AZURE_OPENAI_EMB_MODEL_NAME: embeddingModelName
//       AZURE_OPENAI_CHATGPT_MODEL: chatGptModelName
//       // Used only with non-Azure OpenAI deployments
//       // OPENAI_API_KEY: openAiApiKey
//       OPENAI_ORGANIZATION: openAiApiOrganization
//       // Optional login and document level access control system
//       AZURE_USE_AUTHENTICATION: useAuthentication
//       AZURE_SERVER_APP_ID: serverAppId
//       AZURE_SERVER_APP_SECRET: serverAppSecret
//       AZURE_CLIENT_APP_ID: clientAppId
//       AZURE_TENANT_ID: tenant().tenantId
//       // CORS support, for frontends on other hosts
//       ALLOWED_ORIGIN: allowedOrigin
//     }
//   }
// }

module openAi 'core/ai/cognitiveservices.bicep' = if (openAiHost == 'azure') {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiResourceGroupLocation
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: chatGptModelVersion
        }
        sku: {
          name: 'Standard'
          capacity: chatGptDeploymentCapacity
        }
      }
      {
        name: embeddingDeploymentName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
          version: '2'
        }
        capacity: embeddingDeploymentCapacity
      }
    ]
  }
}

module formRecognizer 'core/ai/cognitiveservices.bicep' = {
  name: 'formrecognizer'
  scope: formRecognizerResourceGroup
  params: {
    name: !empty(formRecognizerServiceName) ? formRecognizerServiceName : '${abbrs.cognitiveServicesFormRecognizer}${resourceToken}'
    kind: 'FormRecognizer'
    location: formRecognizerResourceGroupLocation
    tags: tags
    sku: {
      name: formRecognizerSkuName
    }
  }
}

module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: searchServiceResourceGroup
  params: {
    name: !empty(searchServiceName) ? searchServiceName : 'gptkb-${resourceToken}'
    location: !empty(searchServiceLocation) ? searchServiceLocation : location
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: 'free'
  }
}

module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: storageResourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    tags: tags
    publicNetworkAccess: 'Enabled'
    sku: {
      name: storageSkuName
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: storageContainerName
        publicAccess: 'None'
      }
    ]
  }
}

// USER ROLES
module openAiRoleUser 'core/security/role.bicep' = if (openAiHost == 'azure') {
  scope: openAiResourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'User'
  }
}

module formRecognizerRoleUser 'core/security/role.bicep' = {
  scope: formRecognizerResourceGroup
  name: 'formrecognizer-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'User'
  }
}

module storageRoleUser 'core/security/role.bicep' = {
  scope: storageResourceGroup
  name: 'storage-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    principalType: 'User'
  }
}

module storageContribRoleUser 'core/security/role.bicep' = {
  scope: storageResourceGroup
  name: 'storage-contribrole-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: 'User'
  }
}

module searchRoleUser 'core/security/role.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
    principalType: 'User'
  }
}

module searchContribRoleUser 'core/security/role.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: 'User'
  }
}

module searchSvcContribRoleUser 'core/security/role.bicep' = {
  scope: searchServiceResourceGroup
  name: 'search-svccontrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
    principalType: 'User'
  }
}

// SYSTEM IDENTITIES
// module openAiRoleBackend 'core/security/role.bicep' = if (openAiHost == 'azure') {
//   scope: openAiResourceGroup
//   name: 'openai-role-backend'
//   params: {
//     principalId: backend.outputs.identityPrincipalId
//     roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
//     principalType: 'ServicePrincipal'
//   }
// }

// module storageRoleBackend 'core/security/role.bicep' = {
//   scope: storageResourceGroup
//   name: 'storage-role-backend'
//   params: {
//     principalId: backend.outputs.identityPrincipalId
//     roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
//     principalType: 'ServicePrincipal'
//   }
// }

// module searchRoleBackend 'core/security/role.bicep' = {
//   scope: searchServiceResourceGroup
//   name: 'search-role-backend'
//   params: {
//     principalId: backend.outputs.identityPrincipalId
//     roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
//     principalType: 'ServicePrincipal'
//   }
// }

module eventgrid 'core/eventgrid/eventgrid.bicep' = {
  scope:resourceGroup
  name:'jiaoeventgrid'
  params:{
    location:location
    name:!empty(eventgridName) ? eventgridName : '${abbrs.eventGridDomainsTopics}${resourceToken}'
    StorageAccountId:storage.outputs.id
    BlobContainerName: BlobContainerName
  }
  dependsOn:[
    storage
  ]
}

module functionApp 'core/host/function.bicep' = {
  scope:resourceGroup
  name:'${environmentName}-function'
  params:{
    name:!empty(functionAppName) ? functionAppName : '${abbrs.webSitesFunctions}${resourceToken}'
    location:location
    tags: union(tags, { 'azd-service-name': 'backend' })
    runtimeName:'python'
    runtimeVersion:'3.11'
    storageAccountName:storage.outputs.name
    appServicePlanId:appServicePlan.outputs.id
    FormRecognizerName:formRecognizer.outputs.name
    AzureCognitiveSearch: searchService.outputs.name
    ContentSafetyName:contentSafety.outputs.name
    openAiName:openAi.outputs.name
    // linuxFxVersion:BackendImageName
    appSettings:{
      FUNCTIONS_EXTENSION_VERSION :'~4'
      WEBSITES_ENABLE_APP_SERVICE_STORAGE : 'false'
      APPINSIGHTS_INSTRUMENTATIONKEY : monitoring.outputs.applicationInsightsInstrumentationKey
      // AzureWebJobsStorage : 'DefaultEndpointsProtocol=https;AccountName=${storage.outputs.name};AccountKey=${listKeys(storage.outputs.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
      AZURE_OPENAI_MODEL : chatGptModelName
      AZURE_OPENAI_EMBEDDING_MODEL : embeddingModelName
      AZURE_OPENAI_RESOURCE: openAi.name
      // AZURE_OPENAI_KEY : openAiApiKey
      AZURE_BLOB_ACCOUNT_NAME : storage.outputs.name
      // AZURE_BLOB_ACCOUNT_KEY : storage.listKey().keys[0].value
      AZURE_BLOB_CONTAINER_NAME : BlobContainerName
      AZURE_FORM_RECOGNIZER_ENDPOINT : 'https://${location}.api.cognitive.microsoft.com/'
      // AZURE_FORM_RECOGNIZER_KEY: listKeys('Microsoft.CognitiveServices/accounts/${FormRecognizerName}', '2023-05-01').key1
      // AZURE_SEARCH_SERVICE : 'https://${location}.api.cognitive.microsoft.com/'
      AZURE_SEARCH_SERVICE:searchService.outputs.name
      // AZURE_SEARCH_KEY: listAdminKeys('Microsoft.Search/searchServices/${AzureCognitiveSearch}', '2021-04-01-preview').primaryKey
      DOCUMENT_PROCESSING_QUEUE_NAME: QueueName
      AZURE_OPENAI_API_VERSION: AzureOpenAIApiVersion
      AZURE_SEARCH_INDEX: '${environmentName}-index'
      ORCHESTRATION_STRATEGY: 'langchain'
      AZURE_CONTENT_SAFETY_ENDPOINT: 'https://${location}.api.cognitive.microsoft.com/'
      // AZURE_CONTENT_SAFETY_KEY: listKeys('Microsoft.CognitiveServices/accounts/${ContentSafetyName}', '2023-05-01').key1
    }
  }
  dependsOn:[
    storage
  ]
}
module contentSafety './core/ai/cognitiveservices.bicep' = {
  name: 'contentsafety'
  scope: contentsafetyResourceGroup
  params: {
    name: !empty(contentsafetyServiceName) ? contentsafetyServiceName : '${abbrs.cognitiveServicesContentSafety}${resourceToken}'
    kind: 'ContentSafety'
    location: formRecognizerResourceGroupLocation
    tags: tags
    sku: {
      name: formRecognizerSkuName
    }
  }
}

// Container apps host (including container registry)

module containerApps './core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    location: location
    tags: tags
    containerAppsEnvironmentName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
  }
}

// Web frontend
param webContainerAppName string = ''
param webAppExists bool = false
module web './app/web.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: !empty(webContainerAppName) ? webContainerAppName : '${abbrs.appContainerApps}web-${resourceToken}'
    location: location
    tags: tags
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}web-${resourceToken}'
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    exists: webAppExists
    AzureCognitiveSearch:searchService.outputs.name
    formRecognizerName:formRecognizer.outputs.name
    ContentSafetyName:contentSafety.outputs.name
    storageAccountName:storage.outputs.name
    openAiName:openAi.outputs.name
    env:[
      { name: 'APPINSIGHTS_CONNECTION_STRING', value: monitoring.outputs.applicationInsightsConnectionString}
      { name: 'AZURE_SEARCH_SERVICE', value: 'https://${location}.search.windows.net'}
      { name: 'AZURE_SEARCH_INDEX', value: '${environmentName}-index'}
      { name: 'AZURE_SEARCH_CONVERSATIONS_LOG_INDEX', value: 'conversations'}
      // { name: 'AZURE_SEARCH_KEY', value: listAdminKeys('Microsoft.Search/searchServices/${searchService.outputs.name}', '2021-04-01-preview').primaryKey}
      { name: 'AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG', value: 'default'}
      { name: 'AZURE_SEARCH_INDEX_IS_PRECHUNKED', value: 'false'}
      { name: 'AZURE_SEARCH_TOP_K', value: '5'}
      { name: 'AZURE_SEARCH_ENABLE_IN_DOMAIN', value: 'false'}
      { name: 'AZURE_SEARCH_CONTENT_COLUMNS', value: 'content'}
      { name: 'AZURE_SEARCH_FILENAME_COLUMN', value: 'filename'}
      { name: 'AZURE_SEARCH_TITLE_COLUMN', value: 'title'}
      { name: 'AZURE_SEARCH_URL_COLUMN', value: 'url'}
      { name: 'AZURE_OPENAI_RESOURCE', value: openAi.name}
      // { name: 'AZURE_OPENAI_KEY', value: openAiApiKey}
      { name: 'AZURE_OPENAI_MODEL', value: chatGptModelName}
      { name: 'AZURE_OPENAI_MODEL_NAME', value: chatGptModelName}
      { name: 'AZURE_OPENAI_TEMPERATURE', value: '0'}
      { name: 'AZURE_OPENAI_TOP_P', value: '1'}
      { name: 'AZURE_OPENAI_MAX_TOKENS', value: '1000'}
      { name: 'AZURE_OPENAI_STOP_SEQUENCE', value: '\n'}
      { name: 'AZURE_OPENAI_SYSTEM_MESSAGE', value: 'You are an AI assistant that helps people find information.'}
      { name: 'AZURE_OPENAI_API_VERSION', value: AzureOpenAIApiVersion}
      { name: 'AZURE_OPENAI_STREAM', value: 'true'}
      { name: 'AZURE_OPENAI_EMBEDDING_MODEL', value: embeddingModelName}
      { name: 'AZURE_FORM_RECOGNIZER_ENDPOINT', value: 'https://${location}.api.cognitive.microsoft.com/'}
      // { name: 'AZURE_FORM_RECOGNIZER_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${FormRecognizerName}', '2023-05-01').key1}
      { name: 'AZURE_BLOB_ACCOUNT_NAME', value: storage.outputs.name}
      // { name: 'AZURE_BLOB_ACCOUNT_KEY', value: listKeys(StorageAccount.id, '2019-06-01').keys[0].value}
      { name: 'AZURE_BLOB_CONTAINER_NAME', value: BlobContainerName}
      { name: 'ORCHESTRATION_STRATEGY', value: 'openai_function'}
      { name: 'AZURE_CONTENT_SAFETY_ENDPOINT', value: 'https://${location}.api.cognitive.microsoft.com/'}
      // { name: 'AZURE_CONTENT_SAFETY_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${ContentSafetyName}', '2023-05-01').key1}
    ]
  }
}
// WebAdmin 
module webAdmin './app/webAdmin.bicep' = {
  name: 'webadmin'
  scope: resourceGroup
  params: {
    name: !empty(webAdminContainerAppName) ? webAdminContainerAppName : '${abbrs.appContainerApps}webadmin-${resourceToken}'
    location: location
    tags: tags
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}webadmin-${resourceToken}'
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    exists: webAdminAppExists
    AzureCognitiveSearch:searchService.outputs.name
    formRecognizerName:formRecognizer.outputs.name
    ContentSafetyName:contentSafety.outputs.name
    storageAccountName:storage.outputs.name
    openAiName:openAi.outputs.name
    env:[
      { name: 'APPINSIGHTS_CONNECTION_STRING', value: monitoring.outputs.applicationInsightsConnectionString}
      { name: 'AZURE_SEARCH_SERVICE', value: 'https://${location}.search.windows.net'}
      { name: 'AZURE_SEARCH_INDEX', value: '${environmentName}-index'}
      { name: 'AZURE_SEARCH_CONVERSATIONS_LOG_INDEX', value: 'conversations'}
      // { name: 'AZURE_SEARCH_KEY', value: listAdminKeys('Microsoft.Search/searchServices/${searchService.outputs.name}', '2021-04-01-preview').primaryKey}
      { name: 'AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG', value: 'default'}
      { name: 'AZURE_SEARCH_USE_SEMANTIC_SEARCH', value: 'false'}
      { name: 'AZURE_SEARCH_INDEX_IS_PRECHUNKED', value: 'false'}
      { name: 'AZURE_SEARCH_TOP_K', value: '5'}
      { name: 'AZURE_SEARCH_ENABLE_IN_DOMAIN', value: 'false'}
      { name: 'AZURE_SEARCH_CONTENT_COLUMNS', value: 'content'}
      { name: 'AZURE_SEARCH_FILENAME_COLUMN', value: 'filename'}
      { name: 'AZURE_SEARCH_TITLE_COLUMN', value: 'title'}
      { name: 'AZURE_SEARCH_URL_COLUMN', value: 'url'}
      { name: 'AZURE_OPENAI_RESOURCE', value: openAi.name}
      // { name: 'AZURE_OPENAI_KEY', value: openAiApiKey}
      { name: 'AZURE_OPENAI_MODEL', value: chatGptModelName}
      { name: 'AZURE_OPENAI_MODEL_NAME', value: chatGptModelName}
      { name: 'AZURE_OPENAI_TEMPERATURE', value: '0'}
      { name: 'AZURE_OPENAI_TOP_P', value: '1'}
      { name: 'AZURE_OPENAI_MAX_TOKENS', value: '1000'}
      { name: 'AZURE_OPENAI_STOP_SEQUENCE', value: '\n'}
      { name: 'AZURE_OPENAI_SYSTEM_MESSAGE', value: 'You are an AI assistant that helps people find information.'}
      { name: 'AZURE_OPENAI_API_VERSION', value: AzureOpenAIApiVersion}
      { name: 'AZURE_OPENAI_STREAM', value: 'true'}
      { name: 'AZURE_OPENAI_EMBEDDING_MODEL', value: embeddingModelName}
      { name: 'AZURE_FORM_RECOGNIZER_ENDPOINT', value: 'https://${location}.api.cognitive.microsoft.com/'}
      // { name: 'AZURE_FORM_RECOGNIZER_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${FormRecognizerName}', '2023-05-01').key1}
      { name: 'AZURE_BLOB_ACCOUNT_NAME', value: storage.outputs.name}
      // { name: 'AZURE_BLOB_ACCOUNT_KEY', value: listKeys(StorageAccount.id, '2019-06-01').keys[0].value}
      { name: 'AZURE_BLOB_CONTAINER_NAME', value: BlobContainerName}
      { name: 'ORCHESTRATION_STRATEGY', value: 'openai_function'}
      { name: 'AZURE_CONTENT_SAFETY_ENDPOINT', value: 'https://${location}.api.cognitive.microsoft.com/'}
      // { name: 'AZURE_CONTENT_SAFETY_KEY', value: listKeys('Microsoft.CognitiveServices/accounts/${ContentSafetyName}', '2023-05-01').key1}
    ]
  }
}
// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

// Shared by all OpenAI deployments
output OPENAI_HOST string = openAiHost
output AZURE_OPENAI_EMB_MODEL_NAME string = embeddingModelName
output AZURE_OPENAI_CHATGPT_MODEL string = chatGptModelName
// Specific to Azure OpenAI
output AZURE_OPENAI_SERVICE string = (openAiHost == 'azure') ? openAi.outputs.name : ''
output AZURE_OPENAI_RESOURCE_GROUP string = (openAiHost == 'azure') ? openAiResourceGroup.name : ''
output AZURE_OPENAI_CHATGPT_DEPLOYMENT string = (openAiHost == 'azure') ? chatGptDeploymentName : ''
output AZURE_OPENAI_EMB_DEPLOYMENT string = (openAiHost == 'azure') ? embeddingDeploymentName : ''
// Used only with non-Azure OpenAI deployments
output OPENAI_API_KEY string = (openAiHost == 'openai') ? openAiApiKey : ''
output OPENAI_ORGANIZATION string = (openAiHost == 'openai') ? openAiApiOrganization : ''

output AZURE_FORMRECOGNIZER_SERVICE string = formRecognizer.outputs.name
output AZURE_FORMRECOGNIZER_RESOURCE_GROUP string = formRecognizerResourceGroup.name

output AZURE_SEARCH_INDEX string = searchIndexName
output AZURE_SEARCH_SERVICE string = searchService.outputs.name
output AZURE_SEARCH_SERVICE_RESOURCE_GROUP string = searchServiceResourceGroup.name

output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_CONTAINER string = storageContainerName
output AZURE_STORAGE_RESOURCE_GROUP string = storageResourceGroup.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString


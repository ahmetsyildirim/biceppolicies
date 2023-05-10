targetScope = 'subscription'
param diagnosticSettingName string = 'kv-local-diag'
param location string = 'westus'

resource localWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  scope: resourceGroup('myResourceGroup')
  name: 'la-demo-01'
}

resource kvPolicy 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {
  name: 'bicepKvPolicy'
  properties: {
    displayName: 'Keyvault central diagnostics policy'
    description: 'DeployIfNotExists a when diagnostic is not available for the keyvault'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Custom'
      source: 'Bicep'
      version: '0.1.0'
    }
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'microsoft.keyvault/vaults'
          }
        ]
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          roleDefinitionIds: [
            '/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          type: 'Microsoft.Insights/diagnosticSettings'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Insights/diagnosticSettings/logs[*].category'
                equals: 'audit'
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  resourceName: {
                    type: 'String'
                    metadata: {
                      displayName: 'resourceName'
                      description: 'Name of the resource'
                    }
                  }
              }
                variables: {}
                resources: [
                  {
                    type: 'microsoft.keyvault/vaults/providers/diagnosticSettings'
                    apiVersion: '2021-05-01-preview'
                    name: diagnosticSettingName
                    scope: '[concat(parameters(\'resourceName\'),\'/Microsoft.Insights/\', \'-${diagnosticSettingName}\')]'
                    properties: {
                      workspaceId: localWorkspace.id
                      logs: [
                        {
                        category: 'AuditEvent'
                        categoryGroup: null
                        enabled: true
                        retentionPolicy: {
                          days: 90
                          enabled: true
                        }
                      }
                      ]
                      metrics: [
                        {
                        category: 'AllMetrics'
                        enabled: true
                        retentionPolicy: {
                          days: 90
                          enabled: true 
                        }
                        timeGrain: null
                      }
                    ]
                    }
                  }
                ]
              }
            }
              parameters: {
                resourceName: {
                  value: '[field(\'name\')]'
                }
              }
            }
          }
        }
      }
    }
  }


  resource bicepExampleAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
    name: 'bicepExampleAssignment'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      displayName: 'KV diagnostic policy assignement'
      description: 'KV diagnostic policy assignment'
      enforcementMode: 'Default'
      metadata: {
        source: 'Bicep'
        version: '0.1.0'
      }
      policyDefinitionId: kvPolicy.id
      resourceSelectors: [
        {
          name: 'selector'
          selectors: [
            {
              kind: 'resourceType'
              in: [
                'microsoft.keyvault/vaults'
              ]
            }
          ]
        }
      ]
      nonComplianceMessages: [
        {
          message: 'Resource is not compliant with a DeployIfNotExists policy'
        }
      ]
    }
  }

  resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    name: guid(bicepExampleAssignment.name, bicepExampleAssignment.type, subscription().subscriptionId)
    properties: {
      principalId: bicepExampleAssignment.identity.principalId
      roleDefinitionId: '/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' 
    }
  }

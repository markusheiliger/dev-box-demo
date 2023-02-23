targetScope = 'resourceGroup'

// ============================================================================================

param FirewallPolicyName string
param FirewallRuleCollectionGroupName string = 'default'
param FirewallRuleCollectionGroupPriority int = 100
param FirewallRuleCollections array

// ============================================================================================


resource firewallPolicy 'Microsoft.Network/firewallPolicies@2022-07-01' existing = {
  name: FirewallPolicyName
}

resource firewallRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = {
  name: FirewallRuleCollectionGroupName
  parent: firewallPolicy
  properties: {
    priority: FirewallRuleCollectionGroupPriority
    ruleCollections: FirewallRuleCollections
  }
}

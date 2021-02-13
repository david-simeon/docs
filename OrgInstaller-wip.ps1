
$env:PersonalAccessToken = Get-SimeonAzureDevOpsAccessToken
function Invoke-Api {
    param(
        [string]$Uri,
        [string]$Method,
        [string]$Body,
        [string]$ContentType = "application/json",
        [int]$Retries = 3,
        [int]$SecondsDelay = 5
    )
    $retryCount = 0
    $completed = $false
    $response = $null
    $AuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($env:PersonalAccessToken)")) }

# create object for splatting, removing empty keys
$params = @{
    Uri = $Uri
    Method = $Method
    Header = $AuthenicationHeader
    Body = $Body
    ContentType = $ContentType
}
($params.GetEnumerator() | ? { -not $_.Value }) | % { $params.Remove($_.Name) }

    while (-not $completed) {
        try {
            $response = Invoke-RestMethod @params
            if (!$response -or !$response.StatusCode -ne 200) {
                throw "Expecting reponse code 200, was: $($response.StatusCode)"
            }
            $completed = $true
        } catch {
            Write-Host "$(Get-Date -Format G): Request to $url failed. $_"
            if ($retrycount -ge $Retries) {
                Write-Warning "Request to $url failed the maximum number of $retryCount times."
                throw
            } else {
                Write-Warning "Request to $url failed. Retrying in $SecondsDelay seconds."
                Start-Sleep $SecondsDelay
                $retrycount++
            }
        }
    }
    return $response
}

$Organization = "lance0958"
$ProjectName = "Tenants"
$SimeonUserToInviteToOrg = "devops@simeoncloud.com"
$PipelineNotificationEmail ="pipelinenotifications@simeoncloud.com"
# Used for dev purposess
Import-Module .\SimeonInstaller.ps1 -Force

$groups = (Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?api-version=6.1-preview.1" -Method Get).value

if ($SimeonUserToInviteToOrg) {
    # Send invite to org for Simeon User
    $body = @"
    [
        {
            "from": "",
            "op": 0,
            "path": "",
            "value": {
                "accessLevel": {
                    "licensingSource": 1,
                    "accountLicenseType": 2,
                    "msdnLicenseType": 0,
                    "licenseDisplayName": "Basic",
                    "status": 0,
                    "statusMessage": "",
                    "assignmentSource": 1
                },
                "user": {
                    "principalName": "$SimeonUserToInviteToOrg",
                    "subjectKind": "user"
                }
            }
        }
    ]
"@
    Invoke-Api -Uri "https://vsaex.dev.azure.com/$Organization/_apis/UserEntitlements?api-version=6.1-preview.1" -Method Patch -ContentType "application/json-patch+json" -Body $body


    # assign project collection admin
    $groupDescriptor = ($groups|? displayname -eq "Project Collection Administrators").descriptor
    $userDescriptor = ((Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/graph/users?api-version=6.1-preview.1" -Method Get).value |? principalName -eq "$SimeonUserToInviteToOrg").descriptor
    Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/graph/memberships/$userDescriptor/$groupDescriptor`?api-version=6.1-preview.1" -Method Put | Out-Null
}
# Get users after inviting Simeon User
$users = (Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/graph/users?api-version=6.1-preview.1" -Method Get).value

# Set or get Project id
$projectId = ((Invoke-Api -Uri "https://dev.azure.com/$Organization/_apis/projects?api-version=6.1-preview.4" -Method Get).value |? {$_.name -eq "$ProjectName"}).id
if (!$projectId)
{
    $body = @"
    {
        "name": "$ProjectName",
        "description": "",
        "visibility": 0,
        "capabilities": {
            "versioncontrol": {
                "sourceControlType": "Git"
            },
            "processTemplate": {
                "templateTypeId": "b8a3a935-7e91-48b8-a94c-606d37c3e9f2"
            }
        }
    }
"@
    $projectId = ((Invoke-Api -Uri "https://dev.azure.com/$Organization/_apis/projects?api-version=6.1-preview.4" -Method Post -Body $body).value |? {$_.name -eq "$ProjectName"}).id
    $projectId = (Invoke-RestMethod -Headers $AuthenicationHeader -Uri "https://dev.azure.com/$Organization/_apis/projects?api-version=6.1-preview.4" -Method Post -Body $body -ContentType "application/json").id
}



# Pipelines > Settings > uncheck Limit job authorization scope to current project for non-release pipelines (enforceReferencedRepoScopedToken), Limit job authorization scope to referenced Azure DevOps repositories (enforceJobAuthScope), and Limit variables that can be set at queue time (enforceSettableVar)
$body = @"
{
    "contributionIds": [
        "ms.vss-build-web.pipelines-org-settings-data-provider"
    ],
    "dataProviderContext": {
        "properties": {
            "enforceReferencedRepoScopedToken": "false",
            "enforceJobAuthScope": "false",
            "enforceSettableVar": "false"
        }
    }
}
"@
Invoke-Api -Uri "https://dev.azure.com/$Organization/_apis/Contribution/HierarchyQuery?api-version=5.0-preview.1" -Method Post -Body $body | Out-Null

# Permissions > Project Collection Build Service Accounts > Members > Add > Project Collection Build Service
$groupDescriptor = ($groups |? displayname -eq "Project Collection Build Service Accounts").descriptor
$userDescriptor = ($users |? displayName -eq "Project Collection Build Service ($Organization)").descriptor
Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/graph/memberships/$userDescriptor/$groupDescriptor`?api-version=6.1-preview.1" -Method Put | Out-Null

## Project settings
# Overview > uncheck Boards and Test Plans
$body = @"
{
    "featureId": "ms.vss-work.agile",
    "scope": {
        "settingScope": "project",
        "userScoped": false
    },
    "state": 0
}
"@
Invoke-Api -Uri "https://dev.azure.com/$Organization/_apis/FeatureManagement/FeatureStates/host/project/$projectId/ms.vss-work.agile?api-version=4.1-preview.1" -Method Patch -Body $body | Out-Null

# Overview > uncheck Artifacts
$body = @"
{
    "featureId": "ms.feed.feed",
    "scope": {
        "settingScope": "project",
        "userScoped": false
    },
    "state": 0
}
"@
Invoke-Api -Uri "https://dev.azure.com/$Organization/_apis/FeatureManagement/FeatureStates/host/project/$projectId/ms.feed.feed?api-version=4.1-preview.1" -Method Patch -Body $body | Out-Null

#  Permissions > Contributors > Members > Add > $ProjectName Build Service
### Contributors group actions
$groupDescriptor = ($groups |? principalName -eq "[$ProjectName]\Contributors").descriptor
$userDescriptor = ($users |? displayName -eq "$ProjectName Build Service ($Organization)").descriptor
Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/graph/memberships/$userDescriptor/$groupDescriptor`?api-version=6.1-preview.1" -Method Put | Out-Null

# Permissions > Contributors > Members > Add > Project Collection Build Service
$userDescriptor = ($users |? displayName -eq "Project Collection Build Service ($Organization)").descriptor
Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/graph/memberships/$userDescriptor/$groupDescriptor`?api-version=6.1-preview.1" -Method Put | Out-Null

# Repositories > Permissions > Contributors > allow Create repository
$identityDescriptor = ((Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/identities?api-version=6.0&subjectDescriptors=$groupDescriptor" -Method Get).value).descriptor
$body = @"
{
    "token": "repoV2/$projectId/",
    "merge": true,
    "accessControlEntries": [
        {
            "descriptor": "$identityDescriptor",
            "allow": 256,
            "deny": 0,
            "extendedInfo": {
                "effectiveAllow": 256,
                "effectiveDeny": 0,
                "inheritedAllow": 256,
                "inheritedDeny": 0
            }
        }
    ]
}
"@
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/AccessControlEntries/2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87?api-version=5.0" -Method Post -Body $body | Out-Null

# Repositories > Permissions > Project Collection Administrators > allow Force push
$groupDescriptor = ($groups |? { $_.principalName -eq "[$Organization]\Project Collection Administrators" }).descriptor
$identityDescriptor = ((Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/identities?api-version=6.0&subjectDescriptors=$groupDescriptor" -Method Get).value).descriptor
$body = @"
{
    "token": "repoV2/$projectId/",
    "merge": true,
    "accessControlEntries": [
        {
            "descriptor": "$identityDescriptor",
            "allow": 8,
            "deny": 0,
            "extendedInfo": {
                "effectiveAllow": 8,
                "effectiveDeny": 0,
                "inheritedAllow": 8,
                "inheritedDeny": 0
            }
        }
    ]
}
"@
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/AccessControlEntries/2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87?api-version=5.0" -Method Post -Body $body | Out-Null

# Repositories > Permissions > Project Collection Build Service Accounts > allow Force Push
$groupDescriptor = ($groups |? { $_.principalName -eq "[$Organization]\Project Collection Build Service Accounts" }).descriptor
$identityDescriptor = ((Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/identities?api-version=6.0&subjectDescriptors=$groupDescriptor" -Method Get).value).descriptor
$body = @"
{
    "token": "repoV2/$projectId/",
    "merge": true,
    "accessControlEntries": [
        {
            "descriptor": "$identityDescriptor",
            "allow": 8,
            "deny": 0,
            "extendedInfo": {
                "effectiveAllow": 8,
                "effectiveDeny": 0,
                "inheritedAllow": 8,
                "inheritedDeny": 0
            }
        }
    ]
}
"@
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/AccessControlEntries/2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87?api-version=5.0" -Method Post -Body $body | Out-Null

# Pipelines > Settings > uncheck Limit job authorization scope to current project for non-release pipelines
# Limit job authorization scope to referenced Azure DevOps repositories
$body = @"
{
    "contributionIds": [
        "ms.vss-build-web.pipelines-general-settings-data-provider"
    ],
    "dataProviderContext": {
        "properties": {
            "enforceReferencedRepoScopedToken": "false",
            "enforceJobAuthScope": "false",
            "enforceSettableVar": "false",
            "sourcePage": {
                "url": "https://dev.azure.com/$Organization/$ProjectName/_settings/settings",
                "routeId": "ms.vss-admin-web.project-admin-hub-route",
                "routeValues": {
                    "project": "$ProjectName",
                    "adminPivot": "settings",
                    "controller": "ContributedPage",
                    "action": "Execute"
                }
            }
        }
    }
}
"@
Invoke-Api -Uri "https://dev.azure.com/$Organization/_apis/Contribution/HierarchyQuery?api-version=5.0-preview.1" -Method Post -Body $body | Out-Null

# Repositories > rename $ProjectName to default
$repos = (Invoke-Api -Uri "https://dev.azure.com/$Organization/$projectId/_apis/git/repositories?api-version=6.0" -Method Get).value
if ($repos.name -contains "$ProjectName") {
    $repoId = ($repos |? { $_.name -eq "$ProjectName"}).id
    $body = "{""name"":""Default""}"
    Invoke-Api -Uri "https://dev.azure.com/$Organization/$projectId/_apis/git/repositories/$repoId`?api-version=5.0" -Method Patch -Body $body | Out-Null
}

<#
# Create Service connection
$githubAccessToken ="Get from keyvault"
Install-SimeonGitHubServiceConnection -Organization $Organization -Project $ProjectName -GitHubAccessToken $githubAccessToken

# Install Retry failed Pipelines
Install-SimeonRetryPipeline -Organization $organization

# Install SummaryReport pipeline
$emailPw = "Get from keyvault"
Install-SimeonReportingPipeline -FromEmailAddress 'noreply@simeoncloud.com' -FromEmailPw $emailPw -ToBccAddress '70e1ed48.simeoncloud.com@amer.teams.ms' -Organization $organization
#>

# Navigate to Project settings > Service connections > ... > Security > Add > Contributors > set role to Administrator > Add
$groupId = ($groups |? principalName -eq "[$ProjectName]\Contributors").originId
$body = @"
[
    {
        "roleName": "Administrator",
        "userId": "$groupId"
    }
]
"@
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/securityroles/scopes/distributedtask.project.serviceendpointrole/roleassignments/resources/$projectId`?api-version=5.0-preview.1" -Method Put -Body $body | Out-Null


# Pipelines > ... > Manage security > Contributors > ensure Administer build permissions and Edit build pipeline are set to Allow
$groupDescriptor = ($groups |? { $_.principalName -eq "[$ProjectName]\Contributors" }).descriptor
$identityDescriptor = ((Invoke-Api -Uri "https://vssps.dev.azure.com/$Organization/_apis/identities?api-version=6.0&subjectDescriptors=$groupDescriptor" -Method Get).value).descriptor

$body = @"
{
    "token": "$projectId",
    "merge": true,
    "accessControlEntries": [
        {
            "descriptor": "$identityDescriptor",
            "allow": 16384,
            "deny": 0,
            "extendedInfo": {
                "effectiveAllow": 16384,
                "effectiveDeny": 0,
                "inheritedAllow": 16384,
                "inheritedDeny": 0
            }
        }
    ]
}
"@
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/AccessControlEntries/33344d9c-fc72-4d6f-aba5-fa317101a7e9?api-version=5.0" -Method Post -Body $body | Out-Null

$body = @"
{
    "token": "$projectId",
    "merge": true,
    "accessControlEntries": [
        {
            "descriptor": "$identityDescriptor",
            "allow": 2048,
            "deny": 0,
            "extendedInfo": {
                "effectiveAllow": 2048,
                "effectiveDeny": 0,
                "inheritedAllow": 2048,
                "inheritedDeny": 0
            }
        }
    ]
}
"@
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/AccessControlEntries/33344d9c-fc72-4d6f-aba5-fa317101a7e9?api-version=5.0" -Method Post -Body $body

# Install code search Organization settings > Extensions > Browse marketplace > search for Code Search > Get it free
$body = @"
{
    "assignmentType": 0,
    "billingId": null,
    "itemId": "ms.vss-code-search",
    "operationType": 1,
    "quantity": 0,
    "properties": {}
}
"@
Invoke-Api -Uri "https://extmgmt.dev.azure.com/$organization/_apis/ExtensionManagement/AcquisitionRequests?api-version=6.1-preview.1" -Method Post -Body $body

# Project settings > Notifications > New subscription > Build > A build completes > Next > change 'Deliver to' to custom email address > pipelinenotifications@simeoncloud.com
$groupId = ($groups |? {$_.PrincipalName -eq "[$ProjectName]\$ProjectName Team" }).originId
$body = @"
    {
    "description": "A build completes",
    "filter": {
        "eventType": "ms.vss-build.build-completed-event",
        "criteria": {
            "clauses": [
                {
                    "fieldName": "Build reason",
                    "operator": "Does not contain",
                    "value": "-",
                    "index": 0
                }
            ]
        },
        "type": "Expression"
    },
    "notificationEventInformation": null,
    "type": 2,
    "subscriber": {
        "displayName": "[$ProjectName]\\$ProjectName Team",
        "id": "$groupId",
        "uniqueName": "vstfs:///Classification/TeamProject/$projectId\\$ProjectName Team",
        "isContainer": true
    },
    "channel": {
        "type": "EmailHtml",
        "address": $PipelineNotificationEmail,
        "useCustomAddress": true
    },
    "scope": {
        "id": "$projectId"
    },
    "dirty": true
}
"@

Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/notification/Subscriptions?api-version=6.1-preview.1" -Method Post -Body $body | Out-Null

# Disable pipeline notifications
$body = '{"optedOut":true}'
# Build completes
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/notification/Subscriptions/ms.vss-build.build-requested-personal-subscription/UserSettings/$groupId`?api-version=6.1-preview.1" -Method Put -Body $body | Out-Null
# Pull requests
Invoke-Api -Uri "https://dev.azure.com/$organization/_apis/notification/Subscriptions/ms.vss-code.pull-request-updated-subscription/UserSettings/$groupId`?api-version=6.1-preview.1" -Method Put -Body $body | Out-Null


<#
# Get from keyvault by org name - This needs to run from webapp, not installer
$accessToken = ""
$restProps = @{
    Headers = @{ Authorization = "Bearer $accessToken"}
      ContentType = 'application/json'
  }
$url = "https://installer.vault.azure.net/secrets/Simeon-Test"
irm @restProps $url -Method Get

#>

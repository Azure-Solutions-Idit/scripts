# Import Microsoft Graph and Az modules
Import-Module Microsoft.Graph.Users
Import-Module Az

# Connect to Microsoft Graph (if not already connected)
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All Directory.ReadWrite.All"
}

# Description
# This PowerShell script automates the creation of 25 Azure Active Directory (Azure AD) users and assigns them a specific Azure Role (e.g., Contributor) within a given subscription.
# The script uses the Microsoft Graph and Az modules to interact with Azure AD and Azure resources.
# 
# Usage:
# - Update the `DomainName`, `DefaultPassword`, `SubscriptionId`, and `RoleDefinitionName` parameters with appropriate values.
# - Run the script in a PowerShell session with the Microsoft.Graph.Users and Az modules installed.
#
# Author: Idit Bnaya
# Date: 20.11.2024
# Version: 1.0

# Import required modules
Import-Module Microsoft.Graph.Users
Import-Module Az

# Connect to Microsoft Graph (if not already connected)
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All Directory.ReadWrite.All"
}

# Connect to Azure (if not already connected)
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Parameters
$DomainName = "XXX.onmicrosoft.com" # Replace with your Azure AD domain name
$DefaultPassword = "P@ssw0rd!" # Default password for all users
$SubscriptionId = "yourSubscriptioID" # Replace with your Azure Subscription ID
$RoleDefinitionName = "Contributor" # Role to assign

# Set the subscription context
Select-AzSubscription -SubscriptionId $SubscriptionId

# Loop to create 25 users
for ($i = 1; $i -le 25; $i++) {
    $UserName = "user$i" # Usernames will be user1, user2, ...
    $UserPrincipalName = "$UserName@$DomainName"

    # Create the user object
    $User = @{
        accountEnabled = $true
        displayName = $UserName
        mailNickname = $UserName
        userPrincipalName = $UserPrincipalName
        passwordProfile = @{
            password = $DefaultPassword
            forceChangePasswordNextSignIn = $true
        }
    }

    # Create user in Azure AD
    try {
        $NewUser = New-MgUser -BodyParameter $User
        Write-Host "Created user: $UserPrincipalName"

        # Assign Contributor role to the created user
        $UserObjectId = $NewUser.Id
        $Scope = "/subscriptions/$SubscriptionId"

        try {
            New-AzRoleAssignment -ObjectId $UserObjectId `
                                 -RoleDefinitionName $RoleDefinitionName `
                                 -Scope $Scope
            Write-Host "Assigned Contributor role to: $UserPrincipalName"
        } catch {
            Write-Host "Failed to assign Contributor role to: $UserPrincipalName. Error: $_" -ForegroundColor Red
        }
    } catch {
        Write-Host "Failed to create user: $UserPrincipalName. Error: $_" -ForegroundColor Red
    }
}

Write-Host "25 users have been created and assigned Contributor role in the Subscription."


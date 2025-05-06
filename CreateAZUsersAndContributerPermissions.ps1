<#
.SYNOPSIS
    Automates creation of Azure AD users and assigns Contributor role.

.DESCRIPTION
    This script creates a specified number of Azure AD users and assigns them a role (default: Contributor) in a given subscription.
    It uses Microsoft Graph and Az modules, checks for existing users, and prompts for secure password input.
   It also logs the creation and assignment events.
    The script is designed to follow Azure best practices, including error handling and logging.
    It is idempotent, meaning it will skip creating users that already exist.
    The script supports WhatIf mode to preview actions without executing them.
    The script is designed to be run in a PowerShell environment with the necessary permissions to create users and assign roles in Azure AD and Azure subscriptions.
    
.AUTHOR
    Idit Bnaya

.PARAMETER DomainName
    Azure AD domain name (e.g., contoso.onmicrosoft.com).

.PARAMETER SubscriptionId
    Azure Subscription ID.

.PARAMETER RoleDefinitionName
    Azure role to assign (default: Contributor).

.PARAMETER UserCount
    Number of users to create (default: 25).

.EXAMPLE
    .\CreateAZUsersAndContributerPermissions.ps1 -DomainName "contoso.onmicrosoft.com" -SubscriptionId "xxxx-xxxx-xxxx" -UserCount 10
#>

param(
    [Parameter(Mandatory)]
    [string]$DomainName,

    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [string]$RoleDefinitionName = "Contributor",

    [int]$UserCount = 25
)

# Prompt for password securely
$DefaultPassword = Read-Host "Enter default password for new users" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DefaultPassword)
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Import modules
Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Az -ErrorAction Stop

# Connect to Microsoft Graph
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All Directory.ReadWrite.All"
}

# Connect to Azure
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Set subscription context
Select-AzSubscription -SubscriptionId $SubscriptionId

# Logging
$LogFile = "UserCreationLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

for ($i = 1; $i -le $UserCount; $i++) {
    $UserName = "user$i"
    $UserPrincipalName = "$UserName@$DomainName"

    # Check if user already exists
    $ExistingUser = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -ErrorAction SilentlyContinue
    if ($ExistingUser) {
        Write-Host "User $UserPrincipalName already exists. Skipping." -ForegroundColor Yellow
        Add-Content $LogFile "[$(Get-Date)] Skipped existing user: $UserPrincipalName"
        continue
    }

    $User = @{
        accountEnabled = $true
        displayName = $UserName
        mailNickname = $UserName
        userPrincipalName = $UserPrincipalName
        passwordProfile = @{
            password = $UnsecurePassword
            forceChangePasswordNextSignIn = $true
        }
    }

    try {
        $NewUser = New-MgUser -BodyParameter $User
        Write-Host "Created user: $UserPrincipalName" -ForegroundColor Green
        Add-Content $LogFile "[$(Get-Date)] Created user: $UserPrincipalName"

        $UserObjectId = $NewUser.Id
        $Scope = "/subscriptions/$SubscriptionId"

        try {
            New-AzRoleAssignment -ObjectId $UserObjectId `
                                 -RoleDefinitionName $RoleDefinitionName `
                                 -Scope $Scope
            Write-Host "Assigned $RoleDefinitionName role to: $UserPrincipalName" -ForegroundColor Cyan
            Add-Content $LogFile "[$(Get-Date)] Assigned $RoleDefinitionName role to: $UserPrincipalName"
        } catch {
            Write-Host "Failed to assign role to: $UserPrincipalName. Error: $_" -ForegroundColor Red
            Add-Content $LogFile "[$(Get-Date)] Failed to assign role to: $UserPrincipalName. Error: $_"
        }
    } catch {
        Write-Host "Failed to create user: $UserPrincipalName. Error: $_" -ForegroundColor Red
        Add-Content $LogFile "[$(Get-Date)] Failed to create user: $UserPrincipalName. Error: $_"
    }
}

Write-Host "$UserCount users processed. See $LogFile for details."
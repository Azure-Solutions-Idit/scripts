#this script will check for deleted resources in the last 2 hours and compare it to the total number of resources in the subscription.
# If the deleted resources are greater than 25% of the total resources, it will output the names of the deleted resources.
# Connect-AzAccount

# Author: Idit Bnaya
# Version: 1.1

<#
.SYNOPSIS
    Checks for deleted resources in an Azure subscription within a lookback window and compares to total resources.

.DESCRIPTION
    This script queries Azure Activity Logs for deleted resources in the last X minutes and compares the count to the total number of resources in the subscription.
    If the deleted count exceeds a threshold percentage, it outputs details of the deleted resources.
    Implements Azure best practices: parameter validation, error handling, logging, idempotency, and WhatIf support.

.PARAMETER SubscriptionId
    Azure Subscription ID.

.PARAMETER WorkspaceID
    Log Analytics Workspace ID.

.PARAMETER LookbackMinutes
    Lookback window in minutes (default: 120).

.PARAMETER ThresholdPercent
    Threshold percent for deleted resources (default: 25).

.EXAMPLE
    .\checkdeletedResources.ps1 -SubscriptionId "<sub-id>" -WorkspaceID "<workspace-id>" -LookbackMinutes 120 -ThresholdPercent 25
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [Parameter(Mandatory=$true, HelpMessage="Azure Subscription ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="Log Analytics Workspace ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceID,

    [Parameter(HelpMessage="Lookback window in minutes.")]
    [ValidateRange(1,1440)]
    [int]$LookbackMinutes = 120,

    [Parameter(HelpMessage="Threshold percent for deleted resources.")]
    [ValidateRange(1,100)]
    [double]$ThresholdPercent = 25
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format o
    if ($Level -eq "ERROR" -or $Level -eq "FATAL") {
        Write-Error "[$timestamp][$Level] $Message"
    } elseif ($Level -eq "WARN") {
        Write-Warning "[$timestamp][$Level] $Message"
    } else {
        Write-Host "[$timestamp][$Level] $Message"
    }
}

try {
    # Ensure required modules are available
    foreach ($mod in @("Az.Accounts", "Az.ResourceGraph", "Az.OperationalInsights")) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            try {
                Write-Log "Importing module $mod..."
                Import-Module $mod -ErrorAction Stop
            } catch {
                Write-Log "$mod module not found. Please install it before running this script." "ERROR"
                return
            }
        }
    }

    # Set context
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
    Write-Log "Set Azure context to subscription $SubscriptionId."

    # Count all resources
    $countResources = Search-AzGraph -Query 'Resources | summarize count()' -ErrorAction Stop
    $totalResources = $countResources.count_
    Write-Log "Total resources in subscription: $totalResources"

    # Log Analytics queries
    $Query = @"
AzureActivity
| where CategoryValue == 'Administrative' and Authorization contains 'delete'
| where TimeGenerated > ago(${LookbackMinutes}m)
| summarize count()
"@
    $Query2 = @"
AzureActivity
| where CategoryValue == 'Administrative' and Authorization contains 'delete'
| where TimeGenerated > ago(${LookbackMinutes}m)
| distinct OperationNameValue, ResourceId, Resource, Caller, TimeGenerated
"@

    $ResultList = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $Query -ErrorAction Stop | Select-Object -ExpandProperty Results
    $ResultList2 = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $Query2 -ErrorAction Stop | Select-Object -ExpandProperty Results

    $deletedCount = if ($ResultList.count_) { $ResultList.count_ } else { 0 }
    $threshold = [math]::Round($totalResources * ($ThresholdPercent / 100), 2)
    Write-Log "Deleted resources in last $LookbackMinutes minutes: $deletedCount (Threshold: $threshold)"

    if ($deletedCount -gt $threshold) {
        if ($PSCmdlet.ShouldProcess("Subscription $SubscriptionId", "Output deleted resources exceeding threshold")) {
            Write-Log "More than $ThresholdPercent% of resources deleted! Listing deleted resources:" "WARN"
            if ($ResultList2) {
                $ResultList2 | Sort-Object TimeGenerated -Descending | Format-Table OperationNameValue, ResourceId, Resource, Caller, TimeGenerated -AutoSize
            } else {
                Write-Log "No deleted resource details found." "WARN"
            }
        }
    } else {
        Write-Log "Deleted resources are within normal range."
    }
} catch {
    Write-Log "Fatal error: $_" "FATAL"
}

# Usage Example:
# .\checkdeletedResources.ps1 -SubscriptionId "<sub-id>" -WorkspaceID "<workspace-id>" -LookbackMinutes 120 -ThresholdPercent 25 -WhatIf
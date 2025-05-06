# Author: Idit Bnaya
# Version: 1.1

<#
.SYNOPSIS
    Creates CPU metric alerts for all VMs in all subscriptions.

.DESCRIPTION
    This script creates Azure Monitor metric alerts for VM CPU usage, following Azure best practices:
    - Parameter validation
    - Error handling and logging
    - Idempotency (skips existing alerts)
    - Supports WhatIf mode
    - Tags and descriptions for alerts

.PARAMETER ResourceGroupName
    Resource group for the alert rules.

.PARAMETER ActionGroupName
    Name of the action group to use for alerts.

.PARAMETER ActionGroupRG
    Resource group of the action group.

.PARAMETER AlertRulePrefix
    Prefix for alert rule names.

.PARAMETER AlertThreshold
    CPU threshold for alerting.

.PARAMETER AlertSeverity
    Severity of the alert (1=Critical, 4=Verbose).

.PARAMETER WindowMinutes
    Evaluation window in minutes.

.PARAMETER FrequencyMinutes
    Frequency of alert evaluation in minutes.

.PARAMETER Tags
    Hashtable of tags to apply to alert rules.

.PARAMETER Description
    Description for the alert rule.

.EXAMPLE
    .\createCPualert.ps1 -ResourceGroupName "HealthAlertsGP" -ActionGroupName "HealthAlertsGP" -ActionGroupRG "AlertsActionGroups" -AlertThreshold 0.1 -AlertSeverity 3
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [Parameter(Mandatory=$true, HelpMessage="Resource group for alert rules.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true, HelpMessage="Action group name.")]
    [ValidateNotNullOrEmpty()]
    [string]$ActionGroupName,

    [Parameter(Mandatory=$true, HelpMessage="Resource group of the action group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ActionGroupRG,

    [Parameter(HelpMessage="Prefix for alert rule names.")]
    [string]$AlertRulePrefix = "CPUAlert-",

    [Parameter(HelpMessage="CPU threshold for alerting.")]
    [ValidateRange(0,100)]
    [double]$AlertThreshold = 0.1,

    [Parameter(HelpMessage="Alert severity (1=Critical, 4=Verbose).")]
    [ValidateSet(1,2,3,4)]
    [int]$AlertSeverity = 3,

    [Parameter(HelpMessage="Evaluation window in minutes.")]
    [ValidateRange(1,60)]
    [int]$WindowMinutes = 1,

    [Parameter(HelpMessage="Frequency of alert evaluation in minutes.")]
    [ValidateRange(1,60)]
    [int]$FrequencyMinutes = 1,

    [Parameter(HelpMessage="Tags to apply to alert rules.")]
    [hashtable]$Tags = @{'Environment'='Production'},

    [Parameter(HelpMessage="Description for the alert rule.")]
    [string]$Description = "Alert when VM CPU usage exceeds threshold."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format o
    Write-Verbose "[$timestamp][$Level] $Message"
}

try {
    # Ensure Az module is imported
    if (-not (Get-Module -ListAvailable -Name Az)) {
        Write-Error "Az module not found. Please install Az module before running this script."
        return
    }

    # Authenticate if not already
    if (-not (Get-AzContext)) {
        Write-Log "Connecting to Azure..."
        Connect-AzAccount | Out-Null
    }

    $condition = New-AzMetricAlertRuleV2Criteria `
        -MetricName "Percentage CPU" `
        -TimeAggregation Average `
        -Operator GreaterThan `
        -Threshold $AlertThreshold

    $subscriptions = Get-AzSubscription
    foreach ($subscription in $subscriptions) {
        Write-Log "Processing subscription: $($subscription.Name) [$($subscription.Id)]"
        Select-AzSubscription -SubscriptionId $subscription.Id | Out-Null

        $vms = Get-AzVM
        foreach ($vm in $vms) {
            $windowSize = New-TimeSpan -Minutes $WindowMinutes
            $frequency = New-TimeSpan -Minutes $FrequencyMinutes
            $targetResourceId = $vm.Id
            $alertRuleName = "$AlertRulePrefix$($vm.Name)"

            try {
                $actiongroup = Get-AzActionGroup -Name $ActionGroupName -ResourceGroupName $ActionGroupRG -ErrorAction Stop
            } catch {
                Write-Log "Action group '$ActionGroupName' not found in resource group '$ActionGroupRG'. Skipping VM $($vm.Name)." "WARN"
                continue
            }

            # Check if alert already exists
            $existingAlert = Get-AzMetricAlertRuleV2 -ResourceGroupName $ResourceGroupName -Name $alertRuleName -ErrorAction SilentlyContinue
            if ($existingAlert) {
                Write-Log "Alert rule '$alertRuleName' already exists for VM $($vm.Name). Skipping."
                continue
            }

            if ($PSCmdlet.ShouldProcess("VM $($vm.Name)", "Create alert rule '$alertRuleName'")) {
                try {
                    Add-AzMetricAlertRuleV2 `
                        -Name $alertRuleName `
                        -ResourceGroupName $ResourceGroupName `
                        -WindowSize $windowSize `
                        -Frequency $frequency `
                        -TargetResourceId $targetResourceId `
                        -Condition $condition `
                        -ActionGroup $actiongroup  `
                        -Severity $AlertSeverity `
                        -Description $Description `
                        -Tag $Tags | Out-Null
                    Write-Log "Created alert rule '$alertRuleName' for VM $($vm.Name)."
                } catch {
                    Write-Log "Failed to create alert rule '$alertRuleName' for VM $($vm.Name): $_" "ERROR"
                }
            }
        }
    }
    Write-Log "Alert rules creation completed for all subscriptions." "SUCCESS"
} catch {
    Write-Error "Fatal error: $_"
}

# Usage Example:
# .\createCPualert.ps1 -ResourceGroupName "HealthAlertsGP" -ActionGroupName "HealthAlertsGP" -ActionGroupRG "AlertsActionGroups" -AlertThreshold 0.1 -AlertSeverity 3 -Verbose -WhatIf
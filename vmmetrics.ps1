
# This script retrieves CPU, Disk, and Network metrics for all Azure VMs in the subscription.
# Ensure you have the Az module installed and imported



# Author: Idit Bnaya
# Version: 1.0


# Check if Az module is installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Write-Host "Az module not found. Please install Az module before running this script."
    return
}

# Get all VMs
$vms = Get-AzVM

foreach ($vm in $vms) {
    $status = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
    $powerState = $status.Statuses | Where-Object { $_.Code -match 'PowerState' } | Select-Object -ExpandProperty DisplayStatus

    try {
        # Fetch CPU, Disk, and Network metrics
        $cpuMetric = Get-AzMetric -ResourceId $vm.Id -MetricName "Percentage CPU" -AggregationType Average -TimeGrain 00:01:00 -ErrorAction Stop
        $cpuAverage = $cpuMetric.Data[0].Average

        $diskReadMetric = Get-AzMetric -ResourceId $vm.Id -MetricName "Disk Read Bytes" -AggregationType Total -TimeGrain 00:01:00 -ErrorAction Stop
        $diskReadTotal = $diskReadMetric.Data[0].Total

        $diskWriteMetric = Get-AzMetric -ResourceId $vm.Id -MetricName "Disk Write Bytes" -AggregationType Total -TimeGrain 00:01:00 -ErrorAction Stop
        $diskWriteTotal = $diskWriteMetric.Data[0].Total

        $networkInMetric = Get-AzMetric -ResourceId $vm.Id -MetricName "Network In Total" -AggregationType Total -TimeGrain 00:01:00 -ErrorAction Stop
        $networkInTotal = $networkInMetric.Data[0].Total

        $networkOutMetric = Get-AzMetric -ResourceId $vm.Id -MetricName "Network Out Total" -AggregationType Total -TimeGrain 00:01:00 -ErrorAction Stop
        $networkOutTotal = $networkOutMetric.Data[0].Total

    } catch {
        Write-Host "Error fetching metrics for VM: $($vm.Name)"
        continue
    }

    # Output object
    [PSCustomObject]@{
        VMName = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        PowerState = $powerState
        CPUPercentage = $cpuAverage
        DiskReadBytes = $diskReadTotal
        DiskWriteBytes = $diskWriteTotal
        NetworkInTotal = $networkInTotal
        NetworkOutTotal = $networkOutTotal
    }
}
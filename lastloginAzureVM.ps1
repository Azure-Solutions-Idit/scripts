
# This script retrieves the last login event for all VMs in an Azure subscription.
# Ensure you have the Az module installed and imported


## This script retrieves the last login event for all VMs in an Azure subscription.
# Ensure you have the Az module installed and imported

# Get all VMs
$vms = Get-AzVM

foreach ($vm in $vms) {
    # Assuming you have set up PowerShell remoting and have the necessary credentials
    # Change 'username' and 'password' to the appropriate credentials
    $cred = New-Object System.Management.Automation.PSCredential ('username', (ConvertTo-SecureString 'password' -AsPlainText -Force))

    try {
        # Use Invoke-Command to run a script block on the VM
        $scriptBlock = {
            # Query the event log for the latest logon event
            # Event ID 4624 represents a successful logon event in Windows
            Get-EventLog -LogName Security | Where-Object {$_.EventID -eq 4624} | Sort-Object TimeGenerated -Descending | Select-Object -First 1
        }
        
        # Execute the script block on the VM
        $lastLoginEvent = Invoke-Command -ComputerName $vm.Name -Credential $cred -ScriptBlock $scriptBlock -ErrorAction Stop
        Write-Host "Last login event for VM $($vm.Name): $lastLoginEvent"
    } 
    catch {
        Write-Host "Error accessing VM $($vm.Name): $_"
    }
}
    
$MyCredential = 'admin@mngenvmcap773632.onmicrosoft.com'
 $Body = 'Content of mail'
 $subject = 'Mail send from Azure Automation using Office 365'
 $userid=''
 
# Get the PowerShell credential and prints its properties
$Cred = Get-AutomationPSCredential -Name $MyCredential
if ($Cred -eq $null)
{
    Write-Output 'Credential entered: $MyCredential does not exist in the automation service. Please create one `n'   
}
else
{
    $CredUsername = $Cred.UserName
    $CredPassword = $Cred.GetNetworkCredential().Password
    
    Write-Output '-------------------------------------------------------------------------'
    Write-Output 'Credential Properties: '
    Write-Output 'Username: $CredUsername'
    Write-Output 'Password: *** `n'
    Write-Output '-------------------------------------------------------------------------'
   # Write-Output 'Password: $CredPassword `n'
}
    
 
 Send-MailMessage
-To ''
-Subject $subject
-Body $Body
-UseSsl
-Port 587
-SmtpServer 'smtp.office365.com'
-From $userid
-BodyAsHtml
#-Credential $Cred

    Write-Output 'Mail is now send `n'
    Write-Output '-------------------------------------------------------------------------'

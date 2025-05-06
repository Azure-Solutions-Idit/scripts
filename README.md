# scripts

## Script List

- **CreateAZUsersAndContributerPermissions.ps1**  
  Automates creation of Azure AD users and assigns Contributor role in a subscription. Handles idempotency, logging, and error handling.

- **createCPualert.ps1**  
  Creates Azure Monitor metric alerts for VM CPU usage across all subscriptions. Supports parameterization, logging, WhatIf, and best practices.

- **checkdeletedResources.ps1**  
  Checks for deleted resources in a subscription within a lookback window and compares to total resources. Alerts if deletions exceed a threshold.

- **lastloginvms.ps1**  
  Retrieves the last login event for all VMs in a subscription. Supports both Windows and Linux VMs, with error handling and logging.

- **lastloginAzureVM.ps1**  
  Retrieves the last login event for all VMs in a subscription (Windows only). Implements error handling, logging, and credential parameterization.

- **SendEmail.ps1**  
  Sends an email using Office 365 SMTP and Azure Automation credentials. Includes error handling and logging.

- **vmmetrics.ps1**  
  Retrieves CPU, Disk, and Network metrics for all Azure VMs in the subscription. Outputs VM health and performance data.

- **VMPublicIP.ps1**  
  Creates an Azure Policy definition to prevent the creation of virtual machines with public IP addresses.


# IntuneScripts
All my scripts to manage any setting and stuff in and for Intune and related 

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

### Using the Intune Graph API
The Intune Graph API enables access to Intune information programmatically for your tenant, and the API performs the same Intune operations as those available through the Azure Portal.  

Intune provides data into the Microsoft Graph in the same way as other cloud services do, with rich entity information and relationship navigation.  Use Microsoft Graph to combine information from other services and Intune to build rich cross-service applications for IT professionals or end users.     

Script Description:
```
AutoPilotInformation_to_AzureBlob.ps1
```
you should use this Script on a client after you created a Blob Storage on your Azure Tenant to store the File from every Device you get the WindowsAutopilotInfo
```
get-BlobcontainerFiles_add-AutopilotInfoIntune.ps1
```
This is a Runbook you should only use it in a Auzre Automation Account and create first a service account and add the Modules that are needed, any details in the Script 
                                                    
### Contributing

If you'd like to contribute to this sample, feel Free, this samples are "is as it is".
Test it first on a Test-Tenant before integrati it in Productions!!

This project has adopted as Open Source Code, if you need a contact: mirko@colemberg.ch with any additional questions or comments.
For this scripts are no Suppurt in any case or any SLA to help you, this is a community Project, and should be shared as it!
If you have any better Idea, feel free to contribute, cant't wait to make it better.


## Hope it Helps and saves you some time to have a Beer ;-)

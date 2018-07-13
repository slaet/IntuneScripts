workflow ImportCSVAutopilot
{
    # Converter: Wrapping initial script in an InlineScript activity, and passing any parameters for use within the InlineScript
	# Converter: If you want this InlineScript to execute on another host rather than the Automation worker, simply add some combination of -PSComputerName, -PSCredential, -PSConnectionURI, or other workflow common parameters (http://technet.microsoft.com/en-us/library/jj129719.aspx) as parameters of the InlineScript
	inlineScript {
        <#
        .SYNOPSIS
        This Script is created to Use as a RunBook in Azure Automation.
        If you Like to Use it in the fly you have to do some Modifications, espezialy for the Token to access the Graph API.

        Get the WindowsAutoPilotDeviceInformation-CSV File from a Azure Blob storage container, generate a Json File on the Fly and import it to Intune.

        .DESCRIPTION
        This script connects to Azure StorageContainer, also Connectiong to the GraphAPI with the Credentials stored in the Azure Automation Account and uploads the Information
        to Intune as a Autopilot Device.

        We also and have to create a Profile Assigenment Group First, to add the Device after the Import direct to this Group that the Device are ready for Autopilot.

        Before using this script make sure to set the variables: 
        <$StorageAccountKey>
        <$ContainerName>
        <StorageAccountName>
        <$tenant>
        <$intuneAutomationCredential>


        This script is created for usage with Microsoft Intune and Azure Automation!

        .EXAMPLE
        Copy & Past the Script to a Runbuck in the Azure Automation Account and use it from There!

        .NOTES
        Author:    Mirko Colemberg / baseVISION
        Co-Author: Athiraiyan Kugaseelan
        get-Help:  David Falkus
        Contact:   mirko@colemberg.ch
        Date:      11.07.2018


        History
            001: First Version
    

        ExitCodes:
            99001: Could not Write to LogFile
            99002: Could not Write to Windows Log
            99003: Could not Set ExitMessageRegistry

        .LINK

            http://blog.colemberg.ch

        #>

                #region Main Script
        ########################################################

        #region prereq Modules from the Galley
        #In the Azure Automation Account go to Module Gallery and Import the following Modules

        #WindowsAutoPilotIntune
        #AzureAD
        #AzureAD.Storage
        #Azure
        #AzureRM.Storage

        #endregion

        #Set variables as input for the script
       
        #Get Auth Token for Graph REST API
        
        #import-modules
        $AadModule = Import-Module -Name AzureAD -ErrorAction Stop -PassThru
        
        #Change Variable
        $tenant = "zzzzzzzzzzzzzzzz.onmicrosoft.com"

        # Staticvariables
        $intuneAutomationCredential = Get-AutomationPSCredential -Name AutopilotService
        $intuneAutomationAppId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
        [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
        [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
        $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
        $resourceAppIdURI = "https://graph.microsoft.com"
        $authority = "https://login.microsoftonline.com/$tenant/"



        try {

            #static Variables
            $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority 
            # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
            $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
            $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($intuneAutomationCredential.Username, "OptionalDisplayableId")   
            $userCredentials = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential -ArgumentList $intuneAutomationCredential.Username, $intuneAutomationCredential.Password
            $authResult = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($authContext, $resourceAppIdURI, $intuneAutomationAppId, $userCredentials);
            
            if ($authResult.Result.AccessToken) {

                $authHeader = @{

                    'Content-Type'  = 'application/json'

                    'Authorization' = "Bearer " + $authResult.Result.AccessToken

                    'ExpiresOn'     = $authResult.Result.ExpiresOn

                }

            }

            elseif ($authResult.Exception) {

                throw "An error occured getting access token: $($authResult.Exception.InnerException)"

            }

        }

        catch { 

            throw $_.Exception.Message 

        }
        
        #change Variable
		$StorageAccountKey = "zzzzzzzzzzzzzzzz=="
		$StorageAccountName = "zzzzzzzzzzzzzzzz"
		$ContainerName = "zzzzzzzzzzzzzzzzzzz"

        #Static Variable
        $sourceContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey 
		$graphApiVersion = "Beta"
        $DCP_resource = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
        
		#Write-Output $authHeader
		$files = Get-AzureStorageBlob -Context $sourceContext -container $Containername
		
		foreach($file in $files)
        {
    		Get-AzureStorageBlobContent -Container $containername -context $sourceContext -blob $file.name
    		$CSV = Import-CSV $file.Name 

    #creating the Json oon the fly

            $SN = $CSV.'Device Serial Number'
            $HH = $CSV.'Hardware Hash'
            $WPK = $CSV.'Windows Product ID'

$JSON = @"

            {
                "serialNumber": "$SN",
                "productKey": "$WPK",
                "hardwareIdentifier": "$HH",
                "orderIdentifier": ""
            }

"@

    		#Write-Output $JSON
            
            Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post -Body $JSON -ContentType "application/json"
            Remove-AzureStorageBlob -Container $containername -context $sourceContext -Blob $file.Name 
            
		}
	}
}
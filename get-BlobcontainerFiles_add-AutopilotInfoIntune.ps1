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

[CmdletBinding()]
Param(
)
## Manual Variable Definition
########################################################
$DebugPreference = "Continue"
$ScriptVersion = "001"
$ScriptName = "get-BlobcontainerFiles_add-AutopilotInfoIntune"

$LogFilePathFolder     = "C:\Windows\Logs"
$FallbackScriptPath    = "C:\Windows" # This is only used if the filename could not be resolved(IE running in ISE)

# Log Configuration
$DefaultLogOutputMode  = "Console-LogFile" # "Console-LogFile","Console-WindowsEvent","LogFile-WindowsEvent","Console","LogFile","WindowsEvent","All"
$DefaultLogWindowsEventSource = $ScriptName
$DefaultLogWindowsEventLog = "CustomPS"
 
#region Functions
########################################################

function Write-Log {
    <#
    .DESCRIPTION
    Write text to a logfile with the current time.

    .PARAMETER Message
    Specifies the message to log.

    .PARAMETER Type
    Type of Message ("Info","Debug","Warn","Error").

    .PARAMETER OutputMode
    Specifies where the log should be written. Possible values are "Console","LogFile" and "Both".

    .PARAMETER Exception
    You can write an exception object to the log file if there was an exception.

    .EXAMPLE
    Write-Log -Message "Start process XY"

    .NOTES
    This function should be used to log information to console or log file.
    #>
    param(
        [Parameter(Mandatory=$true,Position=1)]
        [String]
        $Message
    ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info","Debug","Warn","Error")]
        [String]
        $Type = "Debug"
    ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Console-LogFile","Console-WindowsEvent","LogFile-WindowsEvent","Console","LogFile","WindowsEvent","All")]
        [String]
        $OutputMode = $DefaultLogOutputMode
    ,
        [Parameter(Mandatory=$false)]
        [Exception]
        $Exception
    )
    
    $DateTimeString = Get-Date -Format "yyyy-MM-dd HH:mm:sszz"
    $Output = ($DateTimeString + "`t" + $Type.ToUpper() + "`t" + $Message)
    if($Exception){
        $ExceptionString =  ("[" + $Exception.GetType().FullName + "] " + $Exception.Message)
        $Output = "$Output - $ExceptionString"
    }

    if ($OutputMode -eq "Console" -OR $OutputMode -eq "Console-LogFile" -OR $OutputMode -eq "Console-WindowsEvent" -OR $OutputMode -eq "All") {
        if($Type -eq "Error"){
            Write-Error $output
        } elseif($Type -eq "Warn"){
            Write-Warning $output
        } elseif($Type -eq "Debug"){
            Write-Debug $output
        } else{
            Write-Verbose $output -Verbose
        }
    }
    
    if ($OutputMode -eq "LogFile" -OR $OutputMode -eq "Console-LogFile" -OR $OutputMode -eq "LogFile-WindowsEvent" -OR $OutputMode -eq "All") {
        try {
            Add-Content $LogFilePath -Value $Output -ErrorAction Stop
        } catch {
            exit 99001
        }
    }

    if ($OutputMode -eq "Console-WindowsEvent" -OR $OutputMode -eq "WindowsEvent" -OR $OutputMode -eq "LogFile-WindowsEvent" -OR $OutputMode -eq "All") {
        try {
            New-EventLog -LogName $DefaultLogWindowsEventLog -Source $DefaultLogWindowsEventSource -ErrorAction SilentlyContinue
            switch ($Type) {
                "Warn" {
                    $EventType = "Warning"
                    break
                }
                "Error" {
                    $EventType = "Error"
                    break
                }
                default {
                    $EventType = "Information"
                }
            }
            Write-EventLog -LogName $DefaultLogWindowsEventLog -Source $DefaultLogWindowsEventSource -EntryType $EventType -EventId 1 -Message $Output -ErrorAction Stop
        } catch {
            exit 99002
        }
    }
}

#endregion

#region Dynamic Variables and Parameters
########################################################

# Try get actual ScriptName
try{
    $CurrentFileNameTemp = $MyInvocation.MyCommand.Name
    If($CurrentFileNameTemp -eq $null -or $CurrentFileNameTemp -eq ""){
        $CurrentFileName = "NotExecutedAsScript"
    } else {
        $CurrentFileName = $CurrentFileNameTemp
    }
} catch {
    $CurrentFileName = $LogFilePathScriptName
}
$LogFilePath = "$LogFilePathFolder\{0}_{1}_{2}.log" -f ($ScriptName -replace ".ps1", ''),$ScriptVersion,(Get-Date -uformat %Y%m%d%H%M)
# Try get actual ScriptPath
try{
    try{ 
        $ScriptPathTemp = Split-Path $MyInvocation.MyCommand.Path
    } catch {

    }
    if([String]::IsNullOrWhiteSpace($ScriptPathTemp)){
        $ScriptPathTemp = Split-Path $MyInvocation.InvocationName
    }

    If([String]::IsNullOrWhiteSpace($ScriptPathTemp)){
        $ScriptPath = $FallbackScriptPath
    } else {
        $ScriptPath = $ScriptPathTemp
    }
} catch {
    $ScriptPath = $FallbackScriptPath
}

#endregion


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

#region Get Auth Token for Graph REST API
#change:
$tenant = "zzzzzzzzzzzzzzzzzz.onmicrosoft.com"

#static:
$intuneAutomationCredential = Get-AutomationPSCredential -Name AutopilotService
$intuneAutomationAppId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
$adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
$redirectUri = "urn:ietf:wg:oauth:2.0:oob"
$resourceAppIdURI = "https://graph.microsoft.com"
$authority = "https://login.microsoftonline.com/$tenant/"



#endregion

#region Get the Access to the StorageContainer to catch the Blob

#change:
$StorageAccountKey = "zzzzzzzzzzzzzzzzz"
$StorageAccountName = "zzzzzzzzzzzzzzzz"
$ContainerName = "zzzzzzzzzzzzzzzzzz"
#static:

$sourceContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey 
$graphApiVersion = "Beta"
$DCP_resource = "deviceManagement/importedWindowsAutopilotDeviceIdentities"
$uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
$files = Get-AzureStorageBlob -Context $sourceContext -container $Containername

#endregion


#region running the Access to the Graph for Intune       

try {
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
        
#endregion

#region catch every file in the SotrageContainer and change it in to a Json and put it to Intune		
foreach($file in $files)
        {
    		Get-AzureStorageBlobContent -Container $containername -context $sourceContext -blob $file.name
    		$CSV = Import-CSV $file.Name 

#Creating the Json on the fly with change the Header Informations on Json
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

            Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Post -Body $JSON -ContentType "application/json"
            Remove-AzureStorageBlob -Container $containername -context $sourceContext -Blob $file.Name 
		}

#endregion


 





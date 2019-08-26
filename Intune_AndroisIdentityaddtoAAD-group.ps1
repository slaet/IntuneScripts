<#
.DESCRIPTION
DESCRIPTION OF YOUR SCRIPT

.EXAMPLE


.NOTES
Author: Athiraiyan Kugaseelan/baseVISION
Tester: Mirko Colemberg/baseVISION
Date:   18.05.2019

History
    001: First versoin

ExitCodes:
    99001: Could not Write to LogFile
    99002: Could not Write to Windows Log
    99003: Could not Set ExitMessageRegistry
    99004: Could not import Intune PowerShell module

#>
[CmdletBinding()]
Param(
)
## Manual Variable Definition
########################################################
$DebugPreference = "Continue"
$ScriptVersion = "005"
$ScriptName = "Intune_AzureAD_AttributeSync"

$LogFilePathFolder     = "C:\Source"
$FallbackScriptPath    = "C:\Windows" # This is only used if the filename could not be resolved(IE running in ISE)

# Log Configuration
$DefaultLogOutputMode  = "LogFile" # "Console-LogFile","Console-WindowsEvent","LogFile-WindowsEvent","Console","LogFile","WindowsEvent","All"
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

function New-Folder{
    <#
    .DESCRIPTION
    Creates a Folder if it's not existing.

    .PARAMETER Path
    Specifies the path of the new folder.

    .EXAMPLE
    CreateFolder "c:\temp"

    .NOTES
    This function creates a folder if doesn't exist.
    #>
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$Path
    )
	# Check if the folder Exists

	if (Test-Path $Path) {
		Write-Log "Folder: $Path Already Exists"
	} else {
		New-Item -Path $Path -type directory | Out-Null
		Write-Log "Creating $Path"
	}
}

function Set-RegValue {
    <#
    .DESCRIPTION
    Set registry value and create parent key if it is not existing.

    .PARAMETER Path
    Registry Path

    .PARAMETER Name
    Name of the Value

    .PARAMETER Value
    Value to set

    .PARAMETER Type
    Type = Binary, DWord, ExpandString, MultiString, String or QWord

    #>
    param(
        [Parameter(Mandatory=$True)]
        [string]$Path,
        [Parameter(Mandatory=$True)]
        [string]$Name,
        [Parameter(Mandatory=$True)]
        [AllowEmptyString()]
        [string]$Value,
        [Parameter(Mandatory=$True)]
        [string]$Type
    )
    
    try {
        $ErrorActionPreference = 'Stop' # convert all errors to terminating errors
        Start-Transaction

	   if (Test-Path $Path -erroraction silentlycontinue) {      
 
        } else {
            New-Item -Path $Path -Force
            Write-Log "Registry key $Path created"  
        } 
        $null = New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force
        Write-Log "Registry Value $Path, $Name, $Type, $Value set"
        Complete-Transaction
    } catch {
        Undo-Transaction
        Write-Log "Registry value not set $Path, $Name, $Value, $Type" -Type Error -Exception $_.Exception
    }
}

function Set-ExitMessageRegistry () {
    <#
    .DESCRIPTION
    Write Time and ExitMessage into Registry. This is used by various reporting scripts and applications like ConfigMgr or the OSI Documentation Script.

    .PARAMETER Scriptname
    The Name of the running Script

    .PARAMETER LogfileLocation
    The Path of the Logfile

    .PARAMETER ExitMessage
    The ExitMessage for the current Script. If no Error set it to Success

    #>
    param(
    [Parameter(Mandatory=$True)]
    [string]$Script = "$ScriptName`_$ScriptVersion`.ps1",
    [Parameter(Mandatory=$False)]
    [string]$LogfileLocation=$LogFilePath,
    [Parameter(Mandatory=$True)]
    [string]$ExitMessage
    )

    $DateTime = Get-Date -f o
    #The registry Key into which the information gets written must be checked and if not existing created
    if((Test-Path "HKLM:\SOFTWARE\_Custom") -eq $False)
    {
        $null = New-Item -Path "HKLM:\SOFTWARE\_Custom"
    }
    if((Test-Path "HKLM:\SOFTWARE\_Custom\Scripts") -eq $False)
    {
        $null = New-Item -Path "HKLM:\SOFTWARE\_Custom\Scripts"
    }
    try { 
        #The new key gets created and the values written into it
        $null = New-Item -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Script" -ErrorAction Stop -Force
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Script" -Name "Scriptname" -Value "$Script" -ErrorAction Stop -Force
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Script" -Name "Time" -Value "$DateTime" -ErrorAction Stop -Force
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Script" -Name "ExitMessage" -Value "$ExitMessage" -ErrorAction Stop -Force
        $null = New-ItemProperty -Path "HKLM:\SOFTWARE\_Custom\Scripts\$Script" -Name "LogfileLocation" -Value "$LogfileLocation" -ErrorAction Stop -Force
    } catch { 
        Write-Log "Set-ExitMessageRegistry failed" -Type Error -Exception $_.Exception
        #If the registry keys can not be written the Error Message is returned and the indication which line (therefore which Entry) had the error
        exit 99003
    }
}
function Get-AuthToken {

    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthToken
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Get-AuthToken
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )
    
    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    
    $tenant = $userUpn.Host
    
    Write-Host "Checking for AzureAD module..."
    
        $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    
        if ($AadModule -eq $null) {
    
            Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
            $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    
        }
    
        if ($AadModule -eq $null) {
            write-host
            write-host "AzureAD Powershell module not installed..." -f Red
            write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
            write-host "Script can't continue..." -f Red
            write-host
            exit
        }
    
    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version
    
        if($AadModule.count -gt 1){
    
            $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
    
            $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }
    
                # Checking if there are multiple versions of the same module found
    
                if($AadModule.count -gt 1){
    
                $aadModule = $AadModule | select -Unique
    
                }
    
            $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
            $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    
        }
    
        else {
    
            $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
            $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    
        }
    
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
     
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
     
    $resourceAppIdURI = "https://graph.microsoft.com"
     
    $authority = "https://login.microsoftonline.com/$Tenant"
     
        try {
    
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    
        # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
    
        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
    
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result
    
            # If the accesstoken is valid then create the authentication header
    
            if($authResult.AccessToken){
    
            # Creating header for Authorization token
    
            $authHeader = @{
                'Content-Type'='application/json'
                'Authorization'="Bearer " + $authResult.AccessToken
                'ExpiresOn'=$authResult.ExpiresOn
                }
    
            return $authHeader
    
            }
    
            else {
    
            Write-Host
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
    
            }
    
        }
    
        catch {
    
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    
        }
    
    }

Function Get-CorporateDeviceIdentifiers(){
    
        <#
        .SYNOPSIS
        This function is used to get Corporate Device Identifiers from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets Corporate Device Identifiers
        .EXAMPLE
        Get-CorporateDeviceIdentifiers
        Returns Corporate Device Identifiers configured in Intune
        .NOTES
        NAME: Get-CorporateDeviceIdentifiers
        #>
        
        [cmdletbinding()]
        
        param
        (
            [Parameter(Mandatory=$false)]
            $DeviceIdentifier
        )
        
        
        $graphApiVersion = "beta"
        
            try {
        
                if($DeviceIdentifier){
        
                    $Resource = "deviceManagement/importedDeviceIdentities?`$filter=contains(importedDeviceIdentifier,'$DeviceIdentifier')"
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        
                }
        
                else {
        
                    $Resource = "deviceManagement/importedDeviceIdentities"
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        
                }
        
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
        
            }
        
            catch {
        
            $ex = $_.Exception
            $errorResponse = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorResponse)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Host "Response content:`n$responseBody" -f Red
            Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
            write-host
            break
        
            }
        
        }

Function Get-AADDeviceDevice(){

<#

.SYNOPSIS

This function is used to get an AAD Device from the Graph API REST interface

.DESCRIPTION

The function connects to the Graph API Interface and gets an AAD Device registered with AAD

.EXAMPLE

Get-AADDevice -DeviceID $DeviceID

Returns an AAD Device from Azure AD

.NOTES

NAME: Get-AADDevice

#>



[cmdletbinding()]



param

(

    $DeviceID

)



# Defining Variables

$graphApiVersion = "v1.0"

$Resource = "devices"

    

    try {



    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$filter=deviceId eq '$DeviceID'"



    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value 



    }



    catch {



    $ex = $_.Exception

    $errorResponse = $ex.Response.GetResponseStream()

    $reader = New-Object System.IO.StreamReader($errorResponse)

    $reader.BaseStream.Position = 0

    $reader.DiscardBufferedData()

    $responseBody = $reader.ReadToEnd();

    Write-Host "Response content:`n$responseBody" -f Red

    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"

    write-host

    break



    }



}

Function Get-AADDeviceGroup(){

<#
.SYNOPSIS
This function is used to get AAD Groups from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Groups registered with AAD
.EXAMPLE
Get-AADGroup
Returns all users registered with Azure AD
.NOTES
NAME: Get-AADGroup
#>

[cmdletbinding()]

param
(
    $GroupName,
    $id,
    [switch]$Members
)

# Defining Variables
$graphApiVersion = "v1.0"
$Group_resource = "groups"
    
    try {

        if($id){

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=id eq '$id'"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

        }
        
        elseif($GroupName -eq "" -or $GroupName -eq $null){
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        
        }

        else {
            
            if(!$Members){

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
            }
            
            elseif($Members){
            
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
            $Group = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            
                if($Group){

                $GID = $Group.id

                $Group.displayName
                write-host

                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)/$GID/Members"
                (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

                }

            }
        
        }

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

Function Add-AADDeviceGroupMember(){

<#
.SYNOPSIS
This function is used to add an member to an AAD Group from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and adds a member to an AAD Group registered with AAD
.EXAMPLE
Add-AADGroupMember -GroupId $GroupId -AADMemberID $AADMemberID
Returns all users registered with Azure AD
.NOTES
NAME: Add-AADGroupMember
#>

[cmdletbinding()]

param
(
    $GroupId,
    $AADMemberId
)

# Defining Variables
$graphApiVersion = "v1.0"
$Resource = "groups"
    
    try {

    $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$GroupId/members/`$ref"

$JSON = @"
{
    "@odata.id": "https://graph.microsoft.com/v1.0/directoryObjects/$AADMemberId"
}
"@

    Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $Json -ContentType "application/json"

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

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

#region Initialization Authentication
########################################################

New-Folder $LogFilePathFolder
Write-Log "Start Script $Scriptname"
$adminUPN= "Mirko@colemberg.ch"
$passWd= "Nickel76"
#$passwd = "01000000d08c9ddf0115d1118c7a00c04fc297eb0100000034c1083580114a4cadfbff955d53e8bc0000000002000000000010660000000100002000000047603a99d09dbed87693026483a622669a853b95f1fa77c44a6db6ca357c5281000000000e8000000002000020000000c29a2684ad7b644a4a36829563e5649d3029bf18b1fa51cfb7f83ffff77c7f0820000000289f32953dabe5dbde505872753cbed276c648d41fb19cb623e0fc83c7e4c1c2400000002fdf8425e80607e201513bfee5a489da72a617f582f8bc50904712761749063e9d8eb01d59218f2d72c262eeb6bf207d4bfc483c2d4e0e09361501d21d362aad" | ConvertTo-SecureString 


#endregion

#region Main Script
########################################################
Write-Log "Try importing Intune PowerShell module"
try
{
    Import-Module Microsoft.Graph.Intune
}catch
{
    Write-Log "Could not import Intune PowerShell module" -Type Error -Exception $_.Exception
    exit 99004
}

$adminPwd= ConvertTo-SecureString -String $passWd -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ($AdminUPN, $adminPwd)
Write-Log "Establishing connection"
$connection = Connect-MSGraph -PSCredential $creds
$global:authToken = Get-AuthToken -User $adminUPN

Write-Log "Getting all corporate identifiers"
#getting corp identifiers
$corpDevices = Get-CorporateDeviceIdentifiers

Write-Log "Getting all enrolled devices"
#getting enrolled devices
$enrolledDevices = Get-IntuneManagedDevice


$AADGroup = "Android-Classroom1"
$GroupId = (Get-AADDeviceGroup -GroupName $AADGroup).id

    if($GroupId -eq $null -or $GroupId -eq ""){
        $newGroup = New-AADGroup -displayName $AADGroup -securityEnabled:$true -mailEnabled:$false -mailNickname $AADGroup
        $GroupId = $newGroup.id
        #Write-Host "AAD Group - '$AADGroup' doesn't exist, please specify a valid AAD Group..." -ForegroundColor Red
        #Write-Host
    }

foreach($corpDevice in $corpDevices)
{
    if($corpDevice.importedDeviceIdentityType -eq "serialNumber")
    {
        if($enrolledDevices.serialNumber -contains $corpDevice.importedDeviceIdentifier)
        { 
            $deviceToUpdate = Get-IntuneManagedDevice -Filter "SerialNumber eq '$($corpDevice.importedDeviceIdentifier)'"
            if($deviceToUpdate -ne $NULL)
            {
                Write-Log "Modifying device with serialnumber '$($corpDevice.importedDeviceIdentifier)'"
                Update-DeviceManagement_ManagedDevices -managedDeviceId $deviceToUpdate.id -managedDeviceName $corpDevice.description
                $AADDevice = Get-AADDeviceDevice -DeviceID $deviceToUpdate.id
                Add-AADDeviceGroupMember -GroupId $GroupId -AADMemberID $AADDevice.id
            }
        }
        
    }
    if($corpDevice.importedDeviceIdentityType -eq "imei")
    {
        $enrolledDevices.imei -contains $corpDevice.importedDeviceIdentifier
        $deviceToUpdate = Get-IntuneManagedDevice -Filter "imei eq '$($corpDevice.importedDeviceIdentifier)'"
        if($deviceToUpdate -ne $NULL)
        {
                Write-Log "Modifying device with serialnumber '$($corpDevice.importedDeviceIdentifier)'"
                Update-DeviceManagement_ManagedDevices -managedDeviceId $deviceToUpdate.id -managedDeviceName $corpDevice.description
                $AADDevice = Get-AADDeviceDevice -DeviceID $deviceToUpdate.id
                Add-AADDeviceGroupMember -GroupId $GroupId -AADMemberID $AADDevice.id
        }
    }
}



#endregion

#region Finishing
########################################################

Write-Log "End Script $Scriptname"

#endregion
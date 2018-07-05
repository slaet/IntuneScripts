<#
.SYNOPSIS

Get the Windows AutoPilot device information and upload it to Azure Blob storage container.

.DESCRIPTION
This script connects to Azure Blob storage container and uses the available script, from the PowerShell Gallery, for collecting Windows AutoPilot device information.
The collected information will be uploaded to Azure storage and the script will clean up anything that was saved locally.
Before using this script make sure to set the values for <StorageAccountKey> and <StorageAccountName>.
This script is created for usage with Microsoft Intune.

.EXAMPLE
powershell -executionPolicy bypass -file “AutoPilotInformation_to_AzureBlob.ps1”

.NOTES
Author:  Mirko Colemberg / baseVISION
Contact: mirko@colemberg.ch
Date:    04.07.2018

Change the <StorageAccountKey> variable
Change the <StorageAccountName> variable
Change the <ContainerName> variable

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
$ScriptName = "EmptyPowershellTemplate"

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

#region Initialization
########################################################

New-Folder $LogFilePathFolder
Write-Log "Start Script $Scriptname"


#endregion

#region Main Script
########################################################
#Set variables as input for the script

$fileName = "$env:COMPUTERNAME.csv"
$workingDirectory = Join-Path $env:WINDIR "Temp"
$StorageAccountKey = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
$StorageAccountName = "zzzzzzzzzzzzzzzzz"
$ctx = New-AzureStorageContext -StorageAccountName $StorageAccountName ` -StorageAccountKey $StorageAccountKey
$ContainerName = "zzzzzzzzzzzzzzzzz"
$localFile = "$workingDirectory\" + "$fileName" 
Set-Location -Path $workingDirectory



#region install Module AzureRM
#Try to install the AzureRM Module
Try {
    Install-Module -Name AzureRM -Force -ErrorAction Stop
    }

#Catch any error and exit the script
Catch {
    Write-Log -Message "FAILED to install the AzureRM Module"
    Exit
      }

#endregion

#region download and install Autopilot script
#Try to save the script from the PowerShell Gallery

Try {
    Save-Script Get-WindowsAutopilotInfo -Path $workingDirectory -ErrorAction Stop
    }

#Catch any error and exit the script
Catch {
    Write-Log -Message "FAILED to save the script"
    Exit
      }

#Try to install the downloaded script
Try {
    Install-Script -Name Get-WindowsAutoPilotInfo -Force -ErrorAction Stop
    }

#Catch any error and exit the script
Catch {
    Write-Log -Message "FAILED to install the script"
    Exit
       }

#endregion

#Try to run the installed script and save the output to the Azure storage
Try {
    Get-WindowsAutoPilotInfo.ps1 -OutputFile $workingDirectory\$fileName -ErrorAction Stop
    }

#Catch any error and exit the script
Catch {
    Write-Log -Message "FAILED to get Windows AutoPilot information"
      }

#Try to uplad the file to Blob Container
Try {
    Set-AzureStorageBlobContent -File $localFile -Container $ContainerName ` -Blob $fileName -Context $ctx
    }

#Catch any error and exit the script
Catch {
    Write-Log -Message "FAILED to upload csv File to the Blob Container"
      }

#Remove the downloaded script and CSV-File

Remove-Item -Path $workingDirectory\Get-WindowsAutoPilotInfo.ps1
Write-Log -Message "Removing Autopilot Script Done"

Remove-Item -Path $workingDirectory\$fileName
Write-Log -Message "Removing the Created CSV File"

#endregion
#endregion

#region Finishing
########################################################

Write-Log "End Script $Scriptname"

#endregion
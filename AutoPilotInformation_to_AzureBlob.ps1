<#

.SYNOPSIS

    Get the Windows AutoPilot device information and upload it to Azure Blob storage container.

.DESCRIPTION

    This script connects to Azure Blob storage container and uses the available script, from the PowerShell Gallery, for collecting Windows AutoPilot device information.

    The collected information will be uploaded to Azure storage and the script will clean up anything that was saved locally.

    Before using this script make sure to set the values for <StorageAccountKey> and <StorageAccountName>.

    This script is created for usage with Microsoft Intune.

.NOTES

    Author: Mirko Colemberg

    Contact: mirko@colemberg.ch

    Date published: 04-06-2018

    Current version: 1.0

    Basic Script is from Peter van der Woude a great Thank you to Him!!!

.LINK

    http://blog.colemberg.ch

.EXAMPLE

    AutoPilotInformation_to_AzureBlob.ps1

#>

Install-Module -Name AzureRM
#Try to install the Azure RM Module

Try {

    Install-Module -Name AzureRM -Force -ErrorAction Stop

}

#Catch any error and exit the script

Catch {

    Write-Output "FAILED to install the AzureRM Module"

    Exit

}



#Set variables as input for the script

$fileName = "$env:COMPUTERNAME.csv"

$workingDirectory = Join-Path $env:WINDIR "Temp"

$StorageAccountKey = "YfNCbesDyyppLnRA/LLtY0wXr1xSWOlB/zyojSltO93tRdXy2o8B/GVmKqcIQTy5muTwm4LRkGr6Ns18rWlryA=="

$StorageAccountName = "autopilotinfos"

$ctx = New-AzureStorageContext -StorageAccountName $StorageAccountName ` -StorageAccountKey $StorageAccountKey

$ContainerName = "collectcsv"


#Try to save the script from the PowerShell Gallery

Try {

    Save-Script Get-WindowsAutopilotInfo -Path $workingDirectory -ErrorAction Stop

}

#Catch any error and exit the script

Catch {

    Write-Output "FAILED to save the script"

    Exit

}



#Set the location to the path of the saved script

Set-Location -Path $workingDirectory



#Try to install the downloaded script

Try {

    Install-Script -Name Get-WindowsAutoPilotInfo -Force -ErrorAction Stop

}

#Catch any error and exit the script

Catch {

    Write-Output "FAILED to install the script"

    Exit

}

#Try to run the installed script and save the output to the Azure storage

Try {

    Get-WindowsAutoPilotInfo.ps1 -OutputFile $workingDirectory\$fileName -ErrorAction Stop

}

#Catch any error and exit the script

Catch {

    Write-Output "FAILED to get Windows AutoPilot information"

}

#Try to uplad the file to Blob Container

Try {
    $BlobName = "$fileName" 
    $localFile = "$workingDirectory\" + "$BlobName" 
    Set-AzureStorageBlobContent -File $localFile -Container $ContainerName ` -Blob $BlobName -Context $ctx

}

#Catch any error and exit the script

Catch {

    Write-Output "FAILED to upload csv File to the Blob Container"

}


#Remove the downloaded script

Remove-Item -Path $workingDirectory\Get-WindowsAutoPilotInfo.ps1

Remove-Item -Path $workingDirectory\$fileName
<#
.SYNOPSIS
    This script creates the App Registration to be used for  Pwsh - MSGraph API.

.DESCRIPTION
    This script creates the App Registration to be used for  Pwsh - MSGraph API.


.PARAMETER appname
    ' Pwsh_Enterprise_AllowedIPs', ' Pwsh_ManagedDevices' is the validation set for the Naming of the AzureAD Application.
    
.INPUTS
    None

.OUTPUTS
    The ClientID and Secret should be recorded for future connections.

.NOTES
    Version:       1.0
    Author:        Austin Schmitz

    Notable issue with import: Agreement.ReadWrite.All may not resolve the GUID correctly. Confirm in the portal the permissions.

.EXAMPLE
    .\ Pwsh-Create-GraphAPIApp.ps1 -appname ' Pwsh_ManagedDevices'

#>

#Create parameter set

[CmdletBinding()]
param (
    [Parameter(Mandatory, HelpMessage = 'Type out " Pwsh_ManagedDevices" for Intune Managed Devices or " Pwsh_Enterprise_AllowedIPs" for Azure Allowed IPs')]
    [ValidateSet(' Pwsh_Enterprise_AllowedIPs', ' Pwsh_ManagedDevices')]
    [String]
    $appname
)

$Global:ModulePath = ($PSCommandPath | Split-Path -Parent) + "\Modules"
$env:PSModulePath = $env:PSModulePath + ";$ModulePath"

$LoginDomain = Read-Host @"
----------------------------------------
Please input either .com or .us
For 'GCC/GCCH/DoD' use ".us"
For Commercial use ".com"

"@
$LoginDomain = 'https://login.microsoftonline' + $LoginDomain

###Import Azure AD & Connect-AzureAD###
Import-Module AzureAD


if ($LoginDomain -match ".us") {
    $Connect = Connect-AzureAD -AzureEnvironmentName AzureUSGovernment
    $Tenant = $Connect.TenantDomain
} else {
    $Connect = Connect-AzureAD
    $Tenant = $Connect.TenantDomain
}


#Create App Registration for MSGraph API
$appURI = "https://$appName.$Tenant"
$myApp = New-AzureADApplication -DisplayName $appName -IdentifierUris $appURI -ReplyUrls $appURI
Write-Host ('Please Record Application ID (ApplicationID): ' + $myApp.AppID) -ForegroundColor Green

#Set Appliction Registration Permissions
$svcprincipalMSG = Get-AzureADServicePrincipal -All $true | Where-Object { $_.DisplayName -eq 'Microsoft Graph' }

$MSG = New-Object -TypeName 'Microsoft.Open.AzureAD.Model.RequiredResourceAccess'
$MSG.ResourceAppId = $svcprincipalMSG.AppId

$arrPermGuids = @()
$arrPermGuids_Application = @('246dd0d5-5bd0-4def-940b-0421030a5b68') #Policy.Read.All

if ($appname -eq ' Pwsh_ManagedDevices') {

    #Create Password Secret for App Registration
    $passwordApp = New-AzureADApplicationPasswordCredential -ObjectId $myApp.ObjectId -CustomKeyIdentifier 'GraphAPIKey' -EndDate (get-date).AddYears(5)
    Write-Host ('Please Record Application Password (ApplicationSecret): ' + $passwordApp.Value) -ForegroundColor Magenta
    #$PW = $passwordApp.Value

    $arrPermGuids = @(
        'ad902697-1014-4ef5-81ef-2b4301988e8c', #Policy.ReadWrite.ConditionalAccess
        '572fea84-0151-49b2-9301-11cb16974376', #Policy.Read.All
        'ef4b5d93-3104-4664-9053-a5c49ab44218', #Agreement.ReadWrite.All
        '0883f392-0a7a-443d-8c76-16a6d39c7b63', #DeviceManagementConfiguration.ReadWrite.All
        '7b3f05d5-f68c-4b8d-8c59-a2ecd12f24af', #DeviceManagementApps.ReadWrite.All
        '0883f392-0a7a-443d-8c76-16a6d39c7b63', #DeviceManagementConfiguration.ReadWrite.All
        'e1fe6dd8-ba31-4d61-89e7-88639da4683d', #User.Read
        'a154be20-db9c-4678-8ab7-66f6cc099a59', #User.Read.All
        '06da0dbc-49e2-44d2-8312-53f166ab848a', #Directory.Read.All
        'bdfbf15f-ee85-4955-8675-146e8e5296b5', #Application.ReadWrite.All
        '662ed50a-ac44-4eef-ad86-62eed9be2a29', #DeviceManagementServiceConfig.ReadWrite.All
        'b27add92-efb2-4f16-84f5-8108ba77985c'  #Policy.ReadWrite.ApplicationConfiguration
    )

    # Scope = Delegated
    $arrPermGuids | ForEach-Object {
        $MSG.ResourceAccess += New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess' -ArgumentList "$_", 'Scope'
    }

    $arrPermGuids_Application += @(
        'c9090d00-6101-42f0-a729-c41074260d47', #Agreement.ReadWrite.All
        '01c0a623-fc9b-48e9-b794-0756f8e8f067', #Policy.ReadWrite.ConditionalAccess
        '9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30', #Application.Read.All
        '78145de6-330d-4800-a6ce-494ff2d33d07', #DeviceManagementApps.ReadWrite.All
        '9241abd9-d0e6-425a-bd4f-47ba86e767a4', #DeviceManagementConfiguration.ReadWrite.All
        '5ac13192-7ace-4fcf-b828-1a26f28068ee'  #DeviceManagementServiceConfig.ReadWrite.All
    )

}

# Scope = Delegated
if ($arrPermGuids.count -ne 0) {
    $arrPermGuids | ForEach-Object {
        $MSG.ResourceAccess += New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess' -ArgumentList "$_", 'Scope'
    }
}

# Role = Application
$arrPermGuids_Application | ForEach-Object {
    $MSG.ResourceAccess += New-Object -TypeName 'Microsoft.Open.AzureAD.Model.ResourceAccess' -ArgumentList "$_", 'Role' 
}

Set-AzureADApplication -ObjectId $myApp.ObjectId -RequiredResourceAccess $MSG

Write-Host "Finished creating AAD Application for $appname"
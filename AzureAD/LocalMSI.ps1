<#
.SYNOPSIS
Assignes an Azure AD service principal to your machine that can be used a local identity for your mashine. 

.DESCRIPTION
Sometimes it's not enough with the Visual Studio login or the az login command for App Service Authentication while developing with active integration testing. 
For expanded functionallity for loging into different other services you might develop as well, this script assignes a "personal" service principal to your
computer that can be used with the App Service Authentication Services to obtain login token and similar for connecting your computer to those services. 

Note that you might need to assign roles to your service principal in the Azure AD portal, and getting a Global Admin to grant access to those roles. 

The generated service principal will have the same name as your account username. 

This script is using a generated certificate to authenticate, which is a lot safer than locally taking care of secrets. 

Use at own risk, and you are yourself responsible to take good care of access to your computer and certificate, and invalidating the certificate and 
certificate login when a slightest suspicion that it is leaked or sent a place it shouldn't be, even when you have used this script. 
#>

If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments -WorkingDirectory $PSScriptRoot
    Break
}

Write-Host "You will now have to log into your account on azure. Note that if you use your account as a guest account in another tenant, this script hasn't been testes and is not intended for other than native accounts towards native resources in a tenant."
Write-Warning "NB: will fail if you screw up and use another account than a native one."
Write-Host "Hit enter when ready"

Read-Host

$x = Connect-AzAccount
$azureConn = Get-AzContext
$principalName = $azureConn.Account.Id.Split("@")[0]

Write-Host "Connected as $principalName"

# Generating personal certificate
Write-Debug "Generating personal certificate"

$certName = $principalName + "MsiCert"

$cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" `
    -Subject "CN=$certName" `
    -KeySpec KeyExchange
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

# Creating new personal service principal
# If it already exists, update certificate
$sp = Get-AzureADServicePrincipal -Filter "DisplayName eq '$principalName'"
$applicationId = $sp.AppId;

if ($sp) {
    Write-Debug "Service princiapl already exists. Updating certificate"
    $existingCredentials = Get-AzureADServicePrincipalKeyCredential -ObjectId $sp.ObjectId
    if ($existingCredentials) {
        Remove-AzADSpCredential -DisplayName $principalName
    }
    New-AzADSpCredential -ObjectId $sp.ObjectId `
        -CertValue $keyValue `
        -EndDate $cert.NotAfter `
        -StartDate $cert.NotBefore
}
else {
    Write-Debug "Creating new personal service principal"
    $sp = New-AzADServicePrincipal -DisplayName $principalName `
        -CertValue $keyValue `
        -EndDate $cert.NotAfter `
        -StartDate $cert.NotBefore

    $applicationId = $sp.ApplicationId;

    Start-Sleep 30

    # Assigning you to the service principal
    Write-Debug "Assigning you to the service principal"

    $x = New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $applicationId
}

# Environment var info
$appId = $applicationId
$tid = $azureConn.Account.Tenants[0]
$ct = $cert.Thumbprint
$envVar = "RunAs=App;AppId=$appId;TenantId=$tid;CertificateThumbprint=$ct;CertificateStoreLocation=CurrentUser"

[Environment]::SetEnvironmentVariable("AzureServicesAuthConnectionString", $envVar, "Machine")

Write-Host "Following line is the connection string you can use as the AzureServicesAuthConnectionString environment variable."
Write-Host "The environment variable is also set on the machine"
Write-Host $envVar

# make sure user has copied info

Read-Host
Write-Warning "Are you sure you have copied the environment variable information? Its quite a job doing this the second time..."
Read-Host

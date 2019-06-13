## Prerequisites

To be able to use the Azure AD powershell scripts you need to install the [Azure AD powershell module from Microsoft](https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0).

```powershell
Install-Module AzureAD
```

You also need to install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest). To verify the installation, run

```powershell
az --version
```

### Role Assignments

Open a powershell window and execute the following command.

```powershell
Connect-AzureAD
```

Now you should be able to assign roles. For example, to give the orders API permission to read customer information, the command could look something like this:

```powershell
.\AssignRole.ps1 -msi "my-orders-api" -resource "my-customer-api" -role "customers.read"
```

The `msi` is the managed identity of the client, while the `resource` is the application you want to communicate with.

> **NOTE**: You need be owner of the `resource` application in Azure AD, otherwise the role assignment will not have any effect and you will not get an error message!
> To verify that you are owner of the resource, navigate to Azure Active Directory -> Enterprise applications -> filter applications by name -> click on the application -> Owners

If your application needs many permissions and maybe even in multiple environments, we recommend to make a powershell script. The script can also be included in your repository. This makes it easier to do code reviews of required roles and also automate role assignments in the deploy pipeline.

Example:

```powershell
param(
    [parameter(mandatory = $false)][string] $environment = "dev"
)

.\AssignRole.ps1 -msi "my-orders-api-$environment" -resource "my-customer-api-$environment" -role "customer.read"
.\AssignRole.ps1 -msi "my-orders-api-$environment" -resource "my-customer-api-$environment" -role "customer.read.sensitive"
.\AssignRole.ps1 -msi "my-orders-api-$environment" -resource "my-invoice-api-$environment" -role "payment.finalize"
.\AssignRole.ps1 -msi "my-orders-api-$environment" -resource "my-shipping-api-$environment" -role "parcel.create"
```

### Local MSI
> **NOTE**: Before proceeding with the creation of a custom service principal for local development, try the options mentioned in [local development authentication](https://docs.microsoft.com/en-us/azure/key-vault/service-to-service-authentication#local-development-authentication) as this is what Microsofts recommends.
> This script should be only used when authenticating from Visual Studio or Azure CLI does not work for you during development/testing.

To enable MSI on your local development machine, open powershell as administrator and execute the following command
```powerhell
Connect-AzureAD
```
and sign in to your Azure account.

Then run
```powershell
.\LocalMSI.ps1
```

This will create the environment variable *AzureServicesAuthConnectionString* with the following value: `RunAs=App;AppId={AppId};TenantId={TenantId};CertificateThumbprint={Thumbprint};CertificateStoreLocation={CurrentUser}`.

`AppId` is the Application ID of the created service principal. `TenantId` is the ID of the tenant you are signed in to.

For more details about the `AzureServiceTokenProvider` connection string support, see [service-to-service authentication](https://docs.microsoft.com/en-us/azure/key-vault/service-to-service-authentication#connection-string-support).

#### Certificate renewal
The created sertificate will be valid for one year by default. To check the expiration date of your certificate, execute the following commands:

```powershell
Get-AzureADServicePrincipal -Filter "DisplayName eq 'username'"
```
where *username* is the name of the user signed in to the machine that executed `LocalMSI.ps1` the first time.
Exmaple output:

```
ObjectId                             AppId                                DisplayName
--------                             -----                                -----------
fdf8d17a-1c8c-4c41-bb82-1fe0d4711237 680ac5a7-3d96-4fb6-878a-eb6d35f24e59 username
```

Then run
```powershell
Get-AzureADServicePrincipalKeyCredential -ObjectId fdf8d17a-1c8c-4c41-bb82-1fe0d4711237
```
Example output:
```
CustomKeyIdentifyer : {15, 128, 56, 235...}
EndDate             : 07-Jun-20 15:18:22
KeyId               : 1eca0ef7-37fd-4ae8-b565-6cadf837b887
StartDate           : 07-Jun-19 14:58:22
Type                : AsymmetricX509Cert
Usage               : Verify
Value               :
```

To renew the certificate, simply run the `LocalMSI.ps1` script again, and it should renew the certificate on the existing service principal and update the environment variable.

## Troubleshooting
- Some of the scripts require powershell to be run as administrator
- Make sure you have the latest version of the [prerequisite](#prerequisites) tooling
- You may have to wait up to 12 hours for role assignments to become active in case old tokens has been cached
- The local MSI environment variable may not be visible to applications (e.g. Visual Studio) until you restart them

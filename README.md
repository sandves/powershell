# Powershell

Collection of powershell scripts.

## Azure AD

To be able to use the Azure AD powershell scripts you need to install the [Azure AD powershell module from Microsoft](https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0).

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

param(
    [parameter(mandatory = $true)][string] $resourceApplicationName, 
    [parameter(mandatory = $true)][string] $roleName,
    [parameter(mandatory = $true)][string] $msiServicePrincipalName
)

# get application registration
Write-Host "Searching for Role named '$roleName' on application registration '$resourceApplicationName'"
$applications = Get-AzureADApplication -SearchString $resourceApplicationName

if ($applications.count -ne 1) {
    throw "Could not find only one application from your search string"
}

$roleId = ""

foreach ($role in $applications.AppRoles) {
    if ($role.Value -eq $roleName) {
        $roleId = $role.Id
        break
    }
}

if ($role -eq "") {
    throw "Could not find the role specified."
}

# get application service principal registration
Write-Host "Serching for service principal registration for application named '$resourceApplicationName'"
$appSP = Get-AzureADServicePrincipal -SearchString $resourceApplicationName | Where-Object {$_.ServicePrincipalType -eq "Application"}

if ($appSP.count -ne 1) {
    $count = $msiSp.count
    throw "Could not find application service principal. Number of SP found: $count"
}

$resourceId = $appSP.ObjectId

# get msi service principal registration
Write-Host "Serching for service principal registration for msi user named '$msiServicePrincipalName'"
$msiSP = Get-AzureADServicePrincipal -SearchString $msiServicePrincipalName | Where-Object {$_.ServicePrincipalType -eq "ManagedIdentity"}

if ($msiSp.count -ne 1) {
    throw "Could not find msi service principal."
}

$msiPrincipalId = $msiSP.ObjectId

# add new role
# Note: This command will fail 90% of the times, but still do everything correct. 
#       It's a problem with the api, and thats why the assignment is checked further down for actuall failure to add role. 
try {
    New-AzureADServiceAppRoleAssignment -ObjectId $msiPrincipalId -PrincipalId $msiPrincipalId -ResourceId $resourceId -Id $roleId
}
catch {
    # ignore
}

$assignments = Get-AzureADServiceAppRoleAssignedTo -ObjectId $msiPrincipalId 

if (-not $assignments.Id -contains $roleId) {
    throw "Doesn't seem like the msi service principal got the role assigned to itself."
}
else {
    Write-Host "Found role on msi sp after assign."
}
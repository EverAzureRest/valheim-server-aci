using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.

Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$params = $Request.Body #| ConvertFrom-Json -ErrorAction 0

if (-not $params) {
    $params = $Request.Body
}

if ($params) {
    $status = [HttpStatusCode]::OK
    $action = $params.action
    $region = $params.region
    $customerId = $params.customerId
    $servername = $params.servername
    $worldname = $params.worldname
    $resourceGroupName = $ENV:AZURE_RG_NAME
    $containerName = $customerId + "-" + $region + "-vhserver"
   
    $password = (Get-AzKeyVaultSecret -VaultName $ENV:AZURE_KEYVAULT_NAME -Name $customerId).SecretValue
    
    if ($action -icontains "start")
    { Write-Output "Starting Valheim Container"
     try 
        {
        $envpass = New-AzContainerInstanceEnvironmentVariableObject -Name "SERVER_PASS" -SecureValue $password
        $envservername = New-AzContainerInstanceEnvironmentVariableObject -Name "SERVER_NAME" -Value $servername
        $envworldname = New-AzContainerInstanceEnvironmentVariableObject -Name "WORLD_NAME" -Value $worldname
        
        $port1 = New-AzContainerInstancePortObject -port 2456 -protocol UDP
        $port2 = New-AzContainerInstancePortObject -port 2457 -protocol UDP

        $vol1 = New-AzContainerGroupVolumeObject -Name $ENV:DATA_SHARE_NAME -AzureFileShareName $ENV:DATA_SHARE_NAME -AzureFileStorageAccountName $ENV:STORAGE_NAME -AzureFileStorageAccountKey (ConvertTo-SecureString $ENV:STORAGE_KEY -AsPlainText -Force)
        $vol2 = New-AzContainerGroupVolumeObject -Name $ENV:CONFIG_SHARE_NAME -AzureFileShareName $ENV:CONFIG_SHARE_NAME -AzureFileStorageAccountName $ENV:STORAGE_NAME -AzureFileStorageAccountKey (ConvertTo-SecureString $ENV:STORAGE_KEY -AsPlainText -Force)
        
        $mount1 = New-AzContainerInstanceVolumeMountObject -Name $ENV:DATA_SHARE_NAME -MountPath "/opt/valheim"
        $mount2 = New-AzContainerInstanceVolumeMountObject -Name $ENV:CONFIG_SHARE_NAME -MountPath "/config"

        $imageRegistryCredential = New-AzContainerGroupImageRegistryCredentialObject -Server $ENV:REGISTRY_SERVER -Username $ENV:REGISTRY_USERNAME -Password (ConvertTo-SecureString $ENV:REGISTRY_PASSWORD -AsPlainText -Force)
        
        $containerProperties = @{
            Image = "$ENV:REGISTRY_SERVER/vallheim-server:latest"
            Name = $containerName
            RequestCPU = 2
            RequestMemoryInGB = 4
            Port = @($port1, $port2)
            EnvironmentVariable = @($envpass, $envservername, $envworldname)
            VolumeMount = @($mount1, $mount2)
        }
        
        $container = New-AzContainerInstanceObject @containerProperties

        $containerParams = @{
            Name = $containerName
            ResourceGroupName = $resourceGroupName
            Container = $container
            Location = $region
            OStype = "Linux"
            IpAddressType = "public"
            ImageRegistryCredential = $imageRegistryCredential
            Volume = @($vol1, $vol2)
        }
    
        $containerGroup = New-AzContainerGroup @containerParams

        $body = Write-Output @{ IPAddress = $containerGroup.IpAddressIP; FQDN = $containerGroup.Fqdn }

        }
        
    catch 
        {
        Write-Error -Message $_.Exception
        $body = throw $_.Exception
        }
    }
    elseif ($action -icontains "stop")
        {
        Write-Output "Stopping Valheim Container"
        try
            {
            Remove-AzContainerGroup -Name $containerName -ResourceGroupName $resourceGroupName
            $body = "$($containerName) deleted"
            }
        catch 
            {
            Write-Error -Message $_.Exception
            $body = throw $_.Exception
            }
        }

}
else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a valid request in the body."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body | ConvertTo-Json
})

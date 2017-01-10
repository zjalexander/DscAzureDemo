#requires -modules AzureRM, MrAazure

##for reference: other SKUs that might be interesting
#Windows Server 2016 Datacenter                                                                                
#Windows Server 2016 - Nano Server

$ErrorActionPreference = "Stop"

$resourceGroup = "dscVmDemo"
$location = "westus"
$vmName = "myVM"
#must be all lowercase
$storageName = "zachalstorage"


function Test-AzureRmEnvironment
{
Param(
[parameter(Mandatory=$true)]  $ResourceGroupName,
[parameter(Mandatory=$true)]  $StorageAcctName,
[parameter(Mandatory=$true)]  $Location
)
    #check to ensure we are logged in
    Test-AzureRmLogin
    
    #check if resource group exists, if not create it
    Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue -ErrorVariable noGroup
    if( $noGroup )
    {
        #create resourcegroup
        New-AzureRmResourceGroup -Name $resourcegroup -Location $location
    } 

    #check to see if storage exists, if not create it

    Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAcctName -ErrorAction Continue -ErrorVariable noStorage
    if ($noStorage)
    {
        #is the proposed name valid?
        $test = Get-AzureRmStorageAccountNameAvailability $storageacctname
        if (!$test.NameAvailable)
        {
            Write-Error $test.Message
            return $false
        }
        #create the account
        else 
        {
            New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -location $location -Name $storageAcctName -SkuName Standard_LRS
        }
    }

}

Test-AzureRmEnvironment -resourceGroupName $resourceGroup -storageAcctName $storageName -location $location


Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroup -StorageAccountName $storageName
$mySubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "mySubnet" -AddressPrefix 10.0.0.0/24
$myVnet = New-AzureRmVirtualNetwork -Name "myVnet" -ResourceGroupName $resourceGroup -Location $location -AddressPrefix 10.0.0.0/16 -Subnet $mySubnet
$myPublicIp = New-AzureRmPublicIpAddress -Name "myPublicIp" -ResourceGroupName $resourceGroup -Location $location -AllocationMethod Dynamic
$myNIC = New-AzureRmNetworkInterface -Name "myNIC" -ResourceGroupName $resourceGroup -Location $location -SubnetId $myVnet.Subnets[0].Id -PublicIpAddressId $myPublicIp.Id
$cred = Get-Credential -Message "Type the name and password of the local administrator account."
$myVm = New-AzureRmVMConfig -VMName $vmName -VMSize "Standard_A0"
$myVM = Set-AzureRmVMOperatingSystem -VM $myVM -Windows -ComputerName "myVM" -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$myVM = Set-AzureRmVMSourceImage -VM $myVM -PublisherName "MicrosoftWindowsServer"-Offer "WindowsServer" -Skus "2016-Datacenter" -Version "latest"
$myVM = Add-AzureRmVMNetworkInterface -VM $myVM -Id $myNIC.Id
$blobPath = "vhds/myOsDisk1.vhd"
$osDiskUri = (Get-AzureRmStorageAccount -ResourceGroupName $resourcegroup).PrimaryEndpoints.Blob.ToString() + $blobPath
$myVM = Set-AzureRmVMOSDisk -VM $myVM -Name "myOsDisk1" -VhdUri $osDiskUri -CreateOption fromImage
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $myVM
Publish-AzureRmVMDscConfiguration -ConfigurationPath .\iisInstall.ps1 -ResourceGroupName $resourceGroup -StorageAccountName $storageName -force
Set-AzureRmVmDscExtension -Version 2.21 -ResourceGroupName $resourceGroup -VMName $vmName -ArchiveStorageAccountName $storageName -ArchiveBlobName iisInstall.ps1.zip -AutoUpdate:$true -ConfigurationName "IISInstall"
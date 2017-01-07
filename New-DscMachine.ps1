#requires -module AzureRM

##first time setup
# Login-AzureRmAccount
# New-AzureRmResourceGroup -Name "dscVmDemo" -Location "West US"
# Get-AzureRmStorageAccountNameAvailability
# New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -location $location -Name "zachalstorage" -SkuName Standard_LRS

###
# 
#Windows Server 2016 Datacenter                                                                                
#Windows Server 2016 - Nano Server

function Initialize
{
    Param($resourceGroup,$location)

}



$resourceGroup = "dscVmDemo"
$location = "westus"
#must be all lowercase
$storageName = "zachalstorage"

#New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -location $location -Name "zachalstorage" -SkuName Standard_LRS



Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroup -StorageAccountName $storageName








$mySubnet = New-AzureRmVirtualNetworkSubnetConfig -Name "mySubnet" -AddressPrefix 10.0.0.0/24
$myVnet = New-AzureRmVirtualNetwork -Name "myVnet" -ResourceGroupName $resourceGroup `
     -Location $location -AddressPrefix 10.0.0.0/16 -Subnet $mySubnet
$myPublicIp = New-AzureRmPublicIpAddress -Name "myPublicIp" -ResourceGroupName $resourceGroup `
     -Location $location -AllocationMethod Dynamic
$myNIC = New-AzureRmNetworkInterface -Name "myNIC" -ResourceGroupName $resourceGroup `
     -Location $location -SubnetId $myVnet.Subnets[0].Id -PublicIpAddressId $myPublicIp.Id
$cred = Get-Credential -Message "Type the name and password of the local administrator account."
$myVm = New-AzureRmVMConfig -VMName "myVM" -VMSize "Standard_A0"
$myVM = Set-AzureRmVMOperatingSystem -VM $myVM -Windows -ComputerName "myVM" -Credential $cred `
     -ProvisionVMAgent -EnableAutoUpdate
$myVM = Set-AzureRmVMSourceImage -VM $myVM -PublisherName "MicrosoftWindowsServer" `
     -Offer "WindowsServer" -Skus "2016-Datacenter" -Version "latest"
$myVM = Add-AzureRmVMNetworkInterface -VM $myVM -Id $myNIC.Id
$blobPath = "vhds/myOsDisk1.vhd"
$osDiskUri = $storageName.PrimaryEndpoints.Blob.ToString() + $blobPath
$myVM = Set-AzureRmVMOSDisk -VM $myVM -Name "myOsDisk1" -VhdUri $osDiskUri -CreateOption fromImage
New-AzureRmVM -ResourceGroupName $myResourceGroup -Location $location -VM $myVM


Publish-AzureRmVMDscConfiguration -ConfigurationPath .\iisInstall.ps1 -ResourceGroupName $resourceGroup -StorageAccountName $storageName

Set-AzureRmVmDscExtension -Version latest -ResourceGroupName $resourceGroup -VMName $vmName -ArchiveStorageAccountName $storageName -ArchiveBlobName iisInstall.ps1.zip -AutoUpdate:$true 
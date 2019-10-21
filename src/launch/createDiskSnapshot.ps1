param (
    [PSCustomObject]$backupDiskLists,
    [String]$today,
    [PSCustomObject]$storageConfig,
    [PSCustomObject]$programEnv,
    [PSCustomObject]$secretKey
)
Import-Module ($env:Azure_Manual_Backup + "src\svc\env.psm1") -Force
$encryptionConfig = getEncryptionConfig
$encryptionConfig.setSecretKey($secretKey)

$clientId = $encryptionConfig.getDecryptedString($programEnv.loginCred.clientId.ToString())
$passwd = $encryptionConfig.getDecryptedString($programEnv.loginCred.password.ToString())
$securePasswd = ConvertTo-SecureString $passwd -AsPlainText -Force
$mycred =  New-Object System.Management.Automation.PSCredential ($clientId, `
                                                                 $securePasswd)

Connect-AzAccount -Credential $mycred `
                  -Tenant $encryptionConfig.getDecryptedString($programEnv.loginCred.tenant) `
                  -Subscription $encryptionConfig.getDecryptedString($programEnv.loginCred.subscription)`
                  -ServicePrincipal

$sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
$saContext = $sa.Context
$cloudTable = (Get-AzStorageTable -Name "disktmp" -Context $saContext).CloudTable

Write-Host $backupDiskLists
foreach ($backupDiskList in $backupDiskLists) {
    $diskSnapShotName = "BS-" + $backupDiskList.Disk + "-D-" + $today
    Write-Host $diskSnapShotName
    try {
        $sourceDisk = Get-AzDisk -ResourceGroupName $backupDiskList.resourceGroup -DiskName $backupDiskList.Disk -ErrorAction SilentlyContinue
        if($sourceDisk) {
            $diskSnapshotConfig = New-AzSnapshotConfig -SourceUri $sourceDisk.Id -Location $sourceDisk.Location -CreateOption copy
            $diskSnapshot = New-AzSnapshot -SnapshotName $diskSnapShotName -Snapshot $diskSnapshotConfig -ResourceGroupName $sourceDisk.ResourceGroupName
            $diskName = $backupDiskList.Disk
            $vmName = $backupDiskList.vmName
            $rsg = $backupDiskList.resourceGroup
            Add-AzTableRow `
                -table $cloudTable `
                -partitionKey "diskName" `
                -rowKey ("$diskSnapShotName") `
                -property @{"vmName" = "$vmName"; "diskName"="$diskName"; "resourceGroup"="$rsg"}            
        } else {
            
        }
    } catch {
        Write-Output $_.Exception
        return
    } finally {

    }
}
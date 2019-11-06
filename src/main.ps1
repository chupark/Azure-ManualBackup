Import-Module ($env:Azure_Manual_Backup + "src\svc\env.psm1") -Force
Import-Module ($env:Azure_Manual_Backup + "src\library\storagequery.psm1") -Force
Import-Module ($env:Azure_Manual_Backup + "src\svc\snapshotTools.psm1") -Force
Import-Module ($env:Azure_Manual_Backup + "src\svc\Tools.psm1") -Force

## load tableStorageClass
## metadata were stored here
$tableStorageConfig = getTableStorageConfig
$tableStorageConfig.setStorageConfigTyping("ManualBackup", "pcwmanualbackup")

## load ENV from Table Storage
$cloudTable = $tableStorageConfig.getCloudTable("meta")
$programEnv = (Get-AzTableRow -Table $cloudTable).config | ConvertFrom-Json
$storageConfig = $programEnv.storageConfig
$keyVaultConfig = $programEnv.keyVaultInfo

## load Encryption Key from Azure Key Vault
$secretKey = (Get-AzKeyVaultSecret -VaultName $keyVaultConfig.name -Name $keyVaultConfig.secret.name).SecretValueText.Split(",")

## BackupSnapshot-D-bizchdb-D-bizchdb-DATA-2019-10-15
## load SnapshotTools Class & key setting
$snapshotTools = getSnapshotTools
$snapshotTools.setStorageConfig($storageConfig)
$snapshotTools.setKey($secretKey)
$today=Get-Date -Format "yyyy-MM-dd--HH-mm"

## load Tools
$validator = getValidator

Write-Host "all configuration loaded"


Write-Host "Start creating snapshot"
$backupDiskLists = (Get-AzTableRow -Table ($tableStorageConfig.getCloudTable("backupLists"))).backupList | ConvertFrom-Json
foreach ($backupDiskList in $backupDiskLists) {
    Start-Job -FilePath ($env:Azure_Manual_Backup + "src\launch\createDiskSnapshot.ps1") `
              -ArgumentList $backupDiskList, $today, $storageConfig, $programEnv, $secretKey
}
Get-Job | Wait-Job
Get-job | Receive-Job
Get-job | Remove-Job


$snapshotTools.setTable("disktmp")
$disktmp = $snapshotTools.selectByTableName()
$snapshotTools.setMadenSnapshot()
$snapshotTools.createSnapshotLock($programEnv)
$madenSnapshotList = $snapshotTools.madenSnapshotList
Write-Host "Creating snapshot is finished"


Write-Host "Start Generating Snapshot SAS"
foreach ($madenSnapshot in $madenSnapshotList) {
    Start-Job -FilePath ($env:Azure_Manual_Backup + "src\launch\generateSnapshotSAS.ps1") `
              -ArgumentList $madenSnapshot, $disktmp, $storageConfig, $programEnv, $secretKey
}
Get-Job | Wait-Job
Get-job | Receive-Job
Get-job | Remove-Job
$snapshotTools.setTable("sas")
$encryptedSASs = $snapshotTools.selectByTableName()


$param = ("encryptedSAS,Etag,PartitionKey,resourceGroup,resourceType,RowKey,TableTimestamp,vmName").Split(",")
$validator.setParameters($param)
$validator.setInputParameters($encryptedSASs[0])
if (!$validator.validation($validator.getInputParameters())){
    return
} else {

}
Write-Host "Generating Snapshot SAS is finished"


Write-Host "Start blob copy"
$snapshotTools.setTable("savedLists")
$snapshotTools.setDestinationContext()
$snapshotTools.snapshotSendToBlob($encryptedSASs)
do {
    $pending = $snapshotTools.getBlobCopyState()
    Write-Host Copy Job Remains $pending -ForegroundColor Green
    Start-Sleep -Seconds 1
    if ($pending -eq 0) {
        Write-Host "All copy job has finished"
    }
} while($pending -ne 0)


$snapshotTools.setTable("savedLists")
$snapshotTools.setDestinationContext()
$pending = $snapshotTools.getBlobCopyState()
$snapshotTools.selectByTableName()


Write-Host "Start Revoke Snapshot SAS"
$snapshotTools.setTable("sas")
$encryptedSASs = $snapshotTools.selectByTableName()
if($pending -eq 0) {
    foreach ($encryptedSAS in $encryptedSASs) {
        Start-Job -FilePath ($env:Azure_Manual_Backup + "src\launch\revokeSnapshotSAS.ps1") -ArgumentList $encryptedSAS, $programEnv, $secretKey
    }
}
Get-Job | Wait-Job
Get-job | Receive-Job
Get-job | Remove-Job
Write-Host "Revoke Snapshot SAS has finished"

$param = ("encryptedSAS,Etag,PartitionKey,resourceGroup,resourceType,RowKey,TableTimestamp,vmName").Split(",")
$validator.setParameters($param)
$validator.setInputParameters($encryptedSAS[0])

if (!$validator.validation($validator.getInputParameters())){
    return
} else {

}

Write-Host "Clear temp table"
$snapshotTools.setTable("sas")
$snapshotTools.deleteByTableName()
$snapshotTools.setTable("disktmp")
$snapshotTools.deleteByTableName()


Write-Host "Delete old Snapshots"
$beforeDate = (Get-Date).AddDays($programEnv.storageConfig.destination.retention * (-1))
$snapshotTools.setTable("savedLists")
$oldDatas = $snapshotTools.selectByDateBefore($beforeDate)
$snapshotTools.setMadenSnapshot()
$snapshotTools.removeSnapshotLock($programEnv)
foreach ($oldData in $oldDatas) {
    Start-Job -FilePath ($env:Azure_Manual_Backup + "src\launch\removeSnapshot.ps1") -ArgumentList $oldData, $programEnv, $secretKey
}
Get-Job | Wait-Job
Get-job | Receive-Job
Get-job | Remove-Job
Write-Host "Delete old Snapshot has finished"


$snapshotTools.setTable("savedLists")
$snapshotTools.deleteByDateBefore($beforeDate)
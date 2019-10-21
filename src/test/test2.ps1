Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\svc\env.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\storagequery.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\svc\snapshotTools.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\svc\Tools.psm1 -Force

## load tableStorageClass
$tableStorageConfig = getTableStorageConfig
$tableStorageConfig.setStorageConfigTyping("ManualBackup", "pcwmanualbackup")

## load ENV from Table Storage
$cloudTable = $tableStorageConfig.getCloudTable("meta")
$programEnv = (Get-AzTableRow -Table $cloudTable).config | ConvertFrom-Json
$storageConfig = $programEnv.storageConfig
$keyVaultConfig = $programEnv.keyVaultInfo

## load Encryption Key from Azure Key Vault
$secretKey = (Get-AzKeyVaultSecret -VaultName $keyVaultConfig.name -Name $keyVaultConfig.secret.name).SecretValueText.Split(",")

## load SnapshotTools Class
$snapshotTools = getSnapshotTools
$snapshotTools.setStorageConfig($storageConfig)
$snapshotTools.setKey($secretKey)
$today=Get-Date -Format "yyyy-MM-dd--HH-mm"

## load Tools
$validator = getValidator



$backupDiskLists = (Get-AzTableRow -Table ($tableStorageConfig.getCloudTable("backupLists"))).backupList | ConvertFrom-Json
foreach ($backupDiskList in $backupDiskLists) {
    Start-Job -FilePath D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\launch\createDiskSnapshot.ps1 `
              -ArgumentList $backupDiskList, $today, $storageConfig, $programEnv, $secretKey
}
Get-Job | Wait-Job


$snapshotTools.setTable("disktmp")
$disktmp = $snapshotTools.selectByTableName()
$snapshotTools.setMadenSnapshot()
$snapshotTools.createSnapshotLock($programEnv)
$madenSnapshotList = $snapshotTools.madenSnapshotList

foreach ($madenSnapshot in $madenSnapshotList) {
    Start-Job -FilePath D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\launch\generateSnapshotSAS.ps1 `
              -ArgumentList $madenSnapshot, $disktmp, $storageConfig, $programEnv, $secretKey
}
Get-Job | Wait-Job
$snapshotTools.setTable("sas")
$encryptedSASs = $snapshotTools.selectByTableName()

$param = ("encryptedSAS,Etag,PartitionKey,resourceGroup,resourceType,RowKey,TableTimestamp,vmName").Split(",")
$validator.setParameters($param)
$validator.setInputParameters($encryptedSAS[0])

if (!$validator.validation($validator.getInputParameters())){
    return
} else {

}

$snapshotTools.setTable("savedLists")
$snapshotTools.setDestinationContext()
$snapshotTools.snapshotSendToBlob($encryptedSASs)
$pending = $snapshotTools.getBlobCopyState()
$snapshotTools.selectByTableName()


$snapshotTools.setTable("sas")
$encryptedSASs = $snapshotTools.selectByTableName()
if($pending -eq 0) {
    foreach ($encryptedSAS in $encryptedSASs) {
        Start-Job -FilePath D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\launch\revokeSnapshotSAS.ps1 -ArgumentList $encryptedSAS, $programEnv, $secretKey
    }
}
Get-Job | Wait-Job

$snapshotTools.setTable("savedLists")
$oldDatas = $snapshotTools.selectByDateBefore($tdy)
$snapshotTools.setMadenSnapshot()
$snapshotTools.removeSnapshotLock($programEnv)

foreach ($oldData in $oldDatas) {
    Start-Job -FilePath D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\launch\removeSnapshot.ps1 -ArgumentList $oldData, $programEnv, $secretKey
}
Get-Job | Wait-Job

$snapshotTools.setTable("sas")
$snapshotTools.selectByTableName()
$snapshotTools.deleteByTableName()
$snapshotTools.setTable("disktmp")
$snapshotTools.selectByTableName()
$snapshotTools.deleteByTableName()
$snapshotTools.setTable("savedLists")
$snapshotTools.selectByTableName()
$snapshotTools.deleteByDateBefore($tdy)
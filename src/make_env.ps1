# meta
# backupLists
# savedLists
# sas
# disktmp

Import-Module ($env:Azure_Manual_Backup + "src\library\tools.psm1") -Force
Import-Module ($env:Azure_Manual_Backup + "src\library\snapshotlib.psm1")-Force
Import-Module ($env:Azure_Manual_Backup + "src\library\storagequery.psm1")-Force
Import-Module ($env:Azure_Manual_Backup + "src\svc\env.psm1")-Force


$snapshotListsCSVs = Import-Csv -Path  ($env:Azure_Manual_Backup + "statics\diskLists.csv")
$programEnv = Get-Content -Raw -Path  ($env:Azure_Manual_Backup + "statics\storageConfig\env.json") -Force | ConvertFrom-Json
$keyVaultConfig = Get-Content -Raw -Path  ($env:Azure_Manual_Backup + "statics\storageConfig\keyvaultinfo.json") -Force | ConvertFrom-Json
$storageConfig = Get-Content -Raw -Path  ($env:Azure_Manual_Backup + "statics\storageConfig\storageInfo.json") -Force | ConvertFrom-Json


$envConfig = getEnvConfig
$envConfig.generateEncKey()
$envConfig.setkeyVaultConfig($keyVaultConfig)
$envConfig.sendKeyToVault($envConfig.genereatedKey)
$storedKey = $envConfig.getStoredKey()


$tableStorageConfig = getTableStorageConfig
$tableStorageConfig.setStorageConfig($storageConfig)


$encryptionConfig = getEncryptionConfig
$encryptionConfig.setSecretKey($storedKey.SecretValueText.Split(","))
$tmpcred = Get-Content -Path  ($env:Azure_Manual_Backup + "statics\storageConfig\logincred.json") | ConvertFrom-Json
$programEnv.loginCred.clientId = $encryptionConfig.getEncryptedKeyString($tmpcred.clientId)
$programEnv.loginCred.password = $encryptionConfig.getEncryptedKeyString($tmpcred.password)
$programEnv.loginCred.tenant = $encryptionConfig.getEncryptedKeyString($tmpcred.tenant)
$programEnv.loginCred.subscription = $encryptionConfig.getEncryptedKeyString($tmpcred.subscription)


New-AzStorageTable -Context $tableStorageConfig.storageInfo.Context -Name "meta"
New-AzStorageTable -Context $tableStorageConfig.storageInfo.Context -Name "backupLists"
New-AzStorageTable -Context $tableStorageConfig.storageInfo.Context -Name "savedLists"
New-AzStorageTable -Context $tableStorageConfig.storageInfo.Context -Name "sas"
New-AzStorageTable -Context $tableStorageConfig.storageInfo.Context -Name "disktmp"


$cloudTable = $tableStorageConfig.getCloudTable("meta")
Add-AzTableRow -Table $cloudTable `
               -RowKey "allConfig" `
               -PartitionKey "config" `
               -propertyName "config" `
               -jsonString ($programEnv | ConvertTo-Json)
$config = (Get-AzTableRow -Table $cloudTable).config | ConvertFrom-Json
## Remove-AzTableRow -Table $cloudTable -PartitionKey "config" -RowKey "allConfig"



$cloudTable = $tableStorageConfig.getCloudTable($config.vmListsForBackup)
Add-AzTableRow -Table $cloudTable `
               -RowKey "backupList" `
               -PartitionKey "backupList" `
               -propertyName "backupList" `
               -jsonString ($snapshotListsCSVs | ConvertTo-Json)
$backupLists = $null
$backupLists = [String](Get-AzTableRow -Table $cloudTable).backupList | ConvertFrom-Json
## Remove-AzTableRow -Table $cloudTable -RowKey "backupList" -PartitionKey "backupList"
Import-Module -Name "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\encryption.psm1" -Force

$keyVaultConfig = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\keyvaultinfo.json" -Force | ConvertFrom-Json
$storageConfig = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\storageInfo.json" -Force | ConvertFrom-Json
$KeyFileName = $keyVaultConfig.secret.name
$secret = (Get-AzKeyVaultSecret -VaultName $keyVaultConfig.name -Name $keyVaultConfig.secret.name).SecretValueText.Split(",")

$tmpcred = Get-Content -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\logincred.json" | ConvertFrom-Json
$encId = makeEncryptedString -secret $secret -inputString $tmpcred.clientId
$encPW = makeEncryptedString -secret $secret -inputString $tmpcred.password
$encTN = makeEncryptedString -secret $secret -inputString $tmpcred.tenant
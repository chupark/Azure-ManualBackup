## 모듈 임포트
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\tools.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\snapshotlib.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\storagequery.psm1 -Force
Import-Module D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\src\library\encryption.psm1 -Force

## 데이터 로드
$snapshotListsCSVs = Import-Csv -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\diskLists.csv"
# programEnv를 우선 완성 시켜야 함
$programEnv = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\env.json" -Force | ConvertFrom-Json
$storageConfig = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\storageInfo.json" -Force | ConvertFrom-Json
$keyVaultConfig = Get-Content -Raw -Path "D:\PowerShell\PowerShell\AzurePowerShell\dev\SnapShot-Backup-withStorage\statics\storageConfig\keyvaultinfo.json" -Force | ConvertFrom-Json
$sa = Get-AzStorageAccount -ResourceGroupName $storageConfig.saResourceGroup -StorageAccountName $storageConfig.saName
$saContext = $sa.Context

## 암호화 키 생성
$envConfig = [envConfig]::new()
$envConfig.generateEncKey()
$envConfig.setkeyVaultConfig($keyVaultConfig)

## 암호화 키 Vault로 전송
$envConfig.sendKeyToVault($envConfig.genereatedKey)

## 저장소 계정 작업
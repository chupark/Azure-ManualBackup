param (
    [PSCustomObject]$oldDatas,
    [PSCustomObject]$programEnv,
    [PSCustomObject]$secretKey
)
Import-Module ($env:Azure_Manual_Backup + "src\svc\env.psm1") -Force
$encryptionConfig = getEncryptionConfig
$encryptionConfig.setSecretKey($secretKey)

$clientId = $encryptionConfig.getDecryptedString($programEnv.loginCred.clientId.ToString())
$thumbPrint = $encryptionConfig.getDecryptedString($programEnv.loginCred.thumbPrint.ToString())

Connect-AzAccount -ApplicationId $clientId `
                  -CertificateThumbprint $thumbPrint `
                  -Tenant $encryptionConfig.getDecryptedString($programEnv.loginCred.tenant) `
                  -Subscription $encryptionConfig.getDecryptedString($programEnv.loginCred.subscription)`
                  -ServicePrincipal
                  
foreach ($oldData in $oldDatas) {
    Remove-AzSnapshot -ResourceGroupName $oldData.resourceGroup -SnapshotName $oldData.RowKey -Force
}
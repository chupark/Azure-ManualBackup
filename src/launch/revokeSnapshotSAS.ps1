param (
    [PSCustomObject]$encryptedSASs,
    [PSCustomObject]$programEnv,
    [PSCustomObject]$secretKey
)
Import-Module ($env:Azure_Manual_Backup + "src\svc\env.psm1") -Force
$encryptionConfig = getEncryptionConfig
$encryptionConfig.setSecretKey($secretKey)

$clientId = $encryptionConfig.getDecryptedString($programEnv.loginCred.clientId.ToString())
$password = $encryptionConfig.getDecryptedString($programEnv.loginCred.thumbPrint.ToString())
$securePasswd = ConvertTo-SecureString $password -AsPlainText -Force
$mycred =  New-Object System.Management.Automation.PSCredential ($clientId, `
                                                                $securePasswd)

Connect-AzAccount -Credential $mycred `
                  -Tenant $encryptionConfig.getDecryptedString($programEnv.loginCred.tenant) `
                  -Subscription $encryptionConfig.getDecryptedString($programEnv.loginCred.subscription)`
                  -ServicePrincipal

foreach ($encryptedSAS in $encryptedSASs) {
    Revoke-AzSnapshotAccess -ResourceGroupName $encryptedSAS.resourceGroup -SnapshotName $encryptedSAS.RowKey
}
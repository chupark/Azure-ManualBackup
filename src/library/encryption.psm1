function creationEncKey() {
    param(
        [PSCustomObject]$keyVaultConfig
    )
    $CreateKey = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($CreateKey)
    $secretValue = ConvertTo-SecureString ($CreateKey -join (",")) -AsPlainText -Force
    $keyVaultConfig.secret.name = $keyVaultConfig.secret.name
    Set-AzKeyVaultSecret -VaultName $keyVaultConfig.name -Name $keyVaultConfig.secret.name -SecretValue $secretValue
}

function getEncKey() {
    param(
        [PSCustomObject]$keyVaultConfig
    )
    $secret = (Get-AzKeyVaultSecret -VaultName $keyVaultConfig.name -Name $keyVaultConfig.secret.name).SecretValueText.Split(",")

    return ,$secret
}

function makeEncryptedString () {
    param(
        [PSCustomObject]$secret,
        [String]$inputString
    )
    $encryptedString = (ConvertTo-SecureString $inputString -AsPlainText -Force | ConvertFrom-SecureString -key $secret)

    return $encryptedString
}
# SSH公開鍵配置スクリプト for 192.168.111.163
# 対象マシンで実行してください

param(
    [string]$PublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOWpwyRypY3ZufML5xBL7ScrZ74GyjTuOxLXOPI6h+L pc-investigation@192.168.111.163"
)

Write-Host "=== SSH公開鍵配置スクリプト ===" -ForegroundColor Green

# ユーザーホームディレクトリの.sshフォルダを作成
$sshDir = "$env:USERPROFILE\.ssh"
if (!(Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force
    Write-Host "Created directory: $sshDir" -ForegroundColor Yellow
}

# authorized_keysファイルに公開鍵を追加
$authorizedKeysFile = "$sshDir\authorized_keys"
Add-Content -Path $authorizedKeysFile -Value $PublicKey
Write-Host "Added public key to: $authorizedKeysFile" -ForegroundColor Yellow

# ファイル権限を設定（セキュリティ向上）
icacls $sshDir /inheritance:r
icacls $sshDir /grant:r "$env:USERNAME:(OI)(CI)F"
icacls $authorizedKeysFile /inheritance:r
icacls $authorizedKeysFile /grant:r "$env:USERNAME:F"

Write-Host "SSH key setup completed!" -ForegroundColor Green
Write-Host "Public key fingerprint: SHA256:jbq/XsOZV3vYJd8BChJZ1oHVBamOWj8kx2Kwwo0fDJo" -ForegroundColor Cyan

# sshd サービスを再起動
Restart-Service sshd
Write-Host "SSH service restarted" -ForegroundColor Yellow
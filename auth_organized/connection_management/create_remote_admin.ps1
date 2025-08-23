# リモート接続専用管理者ユーザー作成スクリプト
# 対象PC（192.168.111.163）で管理者権限で実行してください

param(
    [string]$Username = "RemoteAdmin",
    [string]$Password = "4Ernfb7E!",
    [string]$Description = "Remote Power Investigation Admin"
)

Write-Host "=== Creating Remote Admin User ===" -ForegroundColor Green
Write-Host "Username: $Username" -ForegroundColor Cyan

# 管理者権限確認
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ このスクリプトは管理者権限で実行する必要があります" -ForegroundColor Red
    Write-Host "PowerShellを右クリック → 「管理者として実行」を選択してください" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    # 1. ユーザーが既に存在するか確認
    Write-Host "`n1. Checking if user exists..." -ForegroundColor Yellow
    $existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    
    if ($existingUser) {
        Write-Host "⚠️ User '$Username' already exists" -ForegroundColor Yellow
        Write-Host "Do you want to reset the password? (Y/N): " -NoNewline -ForegroundColor Cyan
        $choice = Read-Host
        
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            # パスワードリセット
            $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            Set-LocalUser -Name $Username -Password $securePassword
            Write-Host "✅ Password reset for user '$Username'" -ForegroundColor Green
        }
    } else {
        # 2. 新規ユーザー作成
        Write-Host "`n2. Creating new user..." -ForegroundColor Yellow
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        
        New-LocalUser -Name $Username `
                      -Password $securePassword `
                      -Description $Description `
                      -PasswordNeverExpires `
                      -AccountNeverExpires
        
        Write-Host "✅ User '$Username' created successfully" -ForegroundColor Green
    }
    
    # 3. 管理者グループに追加
    Write-Host "`n3. Adding user to Administrators group..." -ForegroundColor Yellow
    
    # 既にメンバーか確認
    $isAdmin = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | 
               Where-Object {$_.Name -like "*$Username"}
    
    if (-not $isAdmin) {
        Add-LocalGroupMember -Group "Administrators" -Member $Username
        Write-Host "✅ User added to Administrators group" -ForegroundColor Green
    } else {
        Write-Host "✅ User is already in Administrators group" -ForegroundColor Green
    }
    
    # 4. Remote Desktop Usersグループに追加（必要な場合）
    Write-Host "`n4. Adding user to Remote Desktop Users group..." -ForegroundColor Yellow
    try {
        $rdpGroup = Get-LocalGroup -Name "Remote Desktop Users" -ErrorAction SilentlyContinue
        if ($rdpGroup) {
            Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username -ErrorAction SilentlyContinue
            Write-Host "✅ User added to Remote Desktop Users group" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Remote Desktop Users group not available" -ForegroundColor Gray
    }
    
    # 5. ユーザー情報確認
    Write-Host "`n5. User information:" -ForegroundColor Yellow
    $user = Get-LocalUser -Name $Username
    Write-Host "Username: $($user.Name)" -ForegroundColor White
    Write-Host "Full Name: $($user.FullName)" -ForegroundColor White
    Write-Host "Description: $($user.Description)" -ForegroundColor White
    Write-Host "Enabled: $($user.Enabled)" -ForegroundColor White
    Write-Host "Password Set: $(if ($user.PasswordRequired) {'Yes'} else {'No'})" -ForegroundColor White
    
    # 6. グループメンバーシップ確認
    Write-Host "`n6. Group memberships:" -ForegroundColor Yellow
    $groups = Get-LocalGroup | Where-Object {
        (Get-LocalGroupMember -Group $_.Name -ErrorAction SilentlyContinue | 
         Where-Object {$_.Name -like "*$Username"}) -ne $null
    }
    foreach ($group in $groups) {
        Write-Host "  - $($group.Name)" -ForegroundColor White
    }
    
    # 7. リモート接続のための追加設定
    Write-Host "`n7. Configuring for remote access..." -ForegroundColor Yellow
    
    # LocalAccountTokenFilterPolicyの設定（リモート管理用）
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $regName = "LocalAccountTokenFilterPolicy"
    
    try {
        $currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        if (-not $currentValue -or $currentValue.$regName -ne 1) {
            New-ItemProperty -Path $regPath -Name $regName -Value 1 -PropertyType DWORD -Force | Out-Null
            Write-Host "✅ LocalAccountTokenFilterPolicy set for remote administration" -ForegroundColor Green
        } else {
            Write-Host "✅ LocalAccountTokenFilterPolicy already configured" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Could not set LocalAccountTokenFilterPolicy" -ForegroundColor Yellow
    }
    
    # 接続情報の表示
    Write-Host "`n" + "=" * 60 -ForegroundColor Green
    Write-Host "✅ Setup Complete!" -ForegroundColor Green
    Write-Host "`n📋 Connection Information:" -ForegroundColor Cyan
    Write-Host "Computer Name: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "IP Address: $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike "127.*"}).IPAddress)" -ForegroundColor White
    Write-Host "Username: $Username" -ForegroundColor White
    Write-Host "Password: $Password" -ForegroundColor White
    
    Write-Host "`n🔧 From investigation PC (192.168.111.55), connect using:" -ForegroundColor Yellow
    Write-Host '$cred = Get-Credential' -ForegroundColor Gray
    Write-Host "# Enter username: $Username" -ForegroundColor Gray
    Write-Host "# Enter password: $Password" -ForegroundColor Gray
    Write-Host 'Enter-PSSession -ComputerName 192.168.111.163 -Credential $cred' -ForegroundColor White
    
    Write-Host "`n⚠️ Security Note:" -ForegroundColor Yellow
    Write-Host "This account should be disabled or removed after investigation is complete" -ForegroundColor White
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to exit"
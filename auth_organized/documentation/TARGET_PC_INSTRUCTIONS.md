# 対象PC（192.168.111.163）実行手順書

## 📋 事前準備
調査側PC（192.168.111.55）のSSHサーバが起動していることを確認済み

## 🚀 実行手順

### 方法1: シンプルなリバースSSH接続（推奨）

対象PCのPowerShellまたはコマンドプロンプトで以下を実行：

```powershell
# リバースSSH接続を確立
ssh -R 3333:localhost:22 hirotaka@192.168.111.55
```

**接続時の操作：**
1. パスワードを入力（調査側PCのhirotakaユーザーのパスワード）
2. 接続が成功したら、そのウィンドウは開いたままにする
3. 調査側PCから `ssh -p 3333 pc@localhost` で対象PCにアクセス可能

---

### 方法2: 自動調査スクリプトを使用

#### ファイル転送（USBメモリ等で）
以下のファイルを対象PCに転送：
- `simple_reverse_connect.ps1`
- `run_reverse_connect.bat`

#### 実行コマンド
```powershell
# PowerShellで実行
powershell -ExecutionPolicy Bypass -File .\simple_reverse_connect.ps1

# またはバッチファイルで実行
.\run_reverse_connect.bat
```

---

### 方法3: カスタム調査サーバに接続

#### ファイル転送
- `target_pc_connector.ps1`

#### 実行コマンド
```powershell
# 調査サーバに接続して電源問題データを自動送信
powershell -ExecutionPolicy Bypass -File .\target_pc_connector.ps1
```

---

## 🔍 接続確認コマンド

接続前に調査側PCへの通信を確認：

```powershell
# 接続テスト
Test-NetConnection -ComputerName 192.168.111.55 -Port 22

# ping確認
ping 192.168.111.55
```

---

## 📊 手動での電源問題調査コマンド

対象PCで直接調査する場合：

```powershell
# 1. 予期しないシャットダウンの確認
Get-EventLog -LogName System | Where-Object {$_.EventID -eq 6008} | Select-Object TimeGenerated,Message -First 10

# 2. 電源関連エラー
Get-EventLog -LogName System -EntryType Error -Newest 20 | Where-Object {$_.Source -like "*Power*"}

# 3. 最後のウェイクアップ情報
powercfg /lastwake

# 4. 電源プラン確認
powercfg /list

# 5. システム情報
systeminfo | findstr /B /C:"OS Name" /C:"System Manufacturer" /C:"System Model"
```

---

## ⚠️ トラブルシューティング

### SSH接続が失敗する場合：

1. **OpenSSH Clientの確認**
```powershell
# OpenSSH Clientがインストールされているか確認
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'

# インストールされていない場合（管理者権限で実行）
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

2. **ファイアウォール確認**
- Windows Defenderファイアウォールで送信接続がブロックされていないか確認
- 企業環境の場合、プロキシやファイアウォール設定を確認

3. **代替ポート使用**
```powershell
# ポート22が使えない場合、別のポートを試す
ssh -p 2222 -R 3333:localhost:22 hirotaka@192.168.111.55
```

---

## 📝 接続成功後の確認

調査側PCで以下を実行して接続を確認：

```bash
# リバース接続の確認
netstat -an | findstr :3333

# 対象PCへのアクセステスト
ssh -p 3333 pc@localhost "echo Connection successful"
```

---

## 🔒 セキュリティ注意事項

- 接続は一時的な調査目的のみ
- 調査完了後は必ず接続を切断（Ctrl+C）
- パスワードは安全に管理
- 不要なファイルは削除

---

## 📞 サポート

問題が発生した場合：
1. 調査側PCのSSHサーバ状態を再確認
2. ネットワーク接続を確認（ping 192.168.111.55）
3. ファイアウォール設定を確認
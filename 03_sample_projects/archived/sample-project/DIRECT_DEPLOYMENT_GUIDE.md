# 🚀 GitHub Actions → MCP Server 直接デプロイガイド

## 📋 実装完了項目

### ✅ 1. Self-hosted Runner セットアップスクリプト
**ファイル:** `setup-selfhosted-runner.sh`
- GitHub Actions runner自動インストール
- MCP統合デプロイスクリプト作成
- 依存関係自動解決
- サービス化対応

### ✅ 2. プロダクション用ワークフロー
**ファイル:** `.github/workflows/production.yml`
- Self-hosted runner使用設定
- MCP API直接連携
- 本格的なデプロイメント処理
- ポストデプロイ検証

### ✅ 3. セキュリティ設定
**GitHub Secrets:** 
- `MCP_SERVER_URL`: http://192.168.111.200:8080
- `DEPLOY_PATH`: /root/mcp_project

## 🎯 デプロイフロー概要

```
GitHub Push → GitHub Actions → Self-hosted Runner → MCP Server
     ↓              ↓                    ↓              ↓
   Code         Test/Build          Direct API      File Deploy
  Changes       (Cloud)            (Same Network)   (Real Server)
```

## 🔧 セットアップ手順

### Step 1: MPCサーバ上でRunner設置
```bash
# MPCサーバ (192.168.111.200) にSSH接続
ssh root@192.168.111.200

# セットアップスクリプト実行
chmod +x setup-selfhosted-runner.sh
sudo ./setup-selfhosted-runner.sh
```

### Step 2: GitHub Runnerの登録
```bash
# GitHub ページでトークン取得
# https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners

# Runner設定実行
sudo -u actions-runner bash -c "cd /home/actions-runner/actions-runner && ./config.sh --url https://github.com/HirotakaKaminishi/mcp-cicd-pipeline --token YOUR_TOKEN --name mcp-server-runner --labels mcp-server,linux,x64,self-hosted --unattended"

# サービス起動
sudo -u actions-runner bash -c "cd /home/actions-runner/actions-runner && ./svc.sh install actions-runner && ./svc.sh start"
```

### Step 3: GitHub Secrets設定
```
Repository Settings → Secrets and variables → Actions

New repository secret:
- Name: MCP_SERVER_URL
  Value: http://192.168.111.200:8080
  
- Name: DEPLOY_PATH  
  Value: /root/mcp_project
```

## 🚀 実行方法

### 自動デプロイ (推奨)
```bash
git push origin main
# → production.yml ワークフローが自動実行
```

### 手動デプロイ
```bash
# GitHub Actions タブ
# → "Production Deployment to MCP Server" 
# → "Run workflow" ボタン
```

## 📊 デプロイワークフロー詳細

### 1. Test Stage (Cloud Runner)
- ESLint品質チェック
- Jest単体テスト実行

### 2. Build Stage (Cloud Runner)  
- npm依存関係インストール
- アプリケーションビルド
- アーティファクト作成・保存

### 3. Deploy Stage (Self-hosted Runner)
- ビルドアーティファクトダウンロード
- MPC API接続確認
- リリースディレクトリ作成
- ファイルデプロイ実行
- シンボリックリンク更新
- サービス再起動

### 4. Verify Stage (Self-hosted Runner)
- デプロイ構造確認
- ヘルスチェック実行
- ログ記録

## 🔍 監視・トラブルシューティング

### Runner状態確認
```bash
# Runner サービス状態
sudo -u actions-runner bash -c "cd /home/actions-runner/actions-runner && ./svc.sh status"

# GitHub でのRunner確認
# https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners
```

### デプロイログ確認
```bash
# MPCサーバ上のデプロイログ
cat /root/mcp_project/deployment.log

# GitHub Actions実行ログ
# https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions
```

### よくある問題と解決方法

**1. Runner接続エラー**
```bash
# Runnerサービス再起動
sudo -u actions-runner bash -c "cd /home/actions-runner/actions-runner && ./svc.sh stop && ./svc.sh start"
```

**2. MCP API接続エラー**
- MCP サーバ状態確認: `systemctl status mcp-server`
- ファイアウォール確認: `firewall-cmd --list-ports`

**3. デプロイ権限エラー**
```bash
# デプロイディレクトリ権限確認
ls -la /root/mcp_project/
chmod 755 /root/mcp_project/
```

## 🌟 メリット

### ✅ 達成できること
- **直接デプロイ:** クラウドからプライベートサーバへの直接配信
- **リアルタイム実行:** ネットワーク制約なしの高速デプロイ
- **完全自動化:** コードプッシュから本番反映まで全自動
- **本格運用:** エンタープライズレベルのCI/CDパイプライン

### 📈 運用効果
- **デプロイ時間:** 従来の手動作業から数分で完了
- **信頼性向上:** 人的ミス排除、一貫性確保
- **変更追跡:** 全デプロイがGitHubで履歴管理
- **ロールバック:** 失敗時の迅速な復旧

---

**🎉 GitHub ActionsからMPCサーバへの直接デプロイ環境構築完了！**
**本格的なDevOpsワークフロー実現準備完了です！**
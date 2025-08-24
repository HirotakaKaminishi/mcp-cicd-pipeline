# 🔐 GitHub Secrets セットアップガイド

## 必要なSecrets設定

GitHub ActionsからMPCサーバに直接デプロイするために、以下のSecretsを設定してください。

### 📋 Settings → Secrets and variables → Actions

**Repository Secrets:**

| Name | Value | Description |
|------|-------|-------------|
| `MCP_SERVER_URL` | `http://192.168.111.200:8080` | MPCサーバのエンドポイントURL |
| `DEPLOY_PATH` | `/root/mcp_project` | デプロイメント先ディレクトリパス |

### 🔧 GitHub Secrets 設定手順

1. **リポジトリ設定にアクセス**
   ```
   https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/secrets/actions
   ```

2. **New repository secret をクリック**

3. **Secret 1: MCP_SERVER_URL**
   - Name: `MCP_SERVER_URL`
   - Secret: `http://192.168.111.200:8080`
   - Add secret をクリック

4. **Secret 2: DEPLOY_PATH**
   - Name: `DEPLOY_PATH`
   - Secret: `/root/mcp_project`
   - Add secret をクリック

### 🏠 Self-hosted Runner セットアップ

**MPCサーバ上で以下を実行:**

```bash
# 1. セットアップスクリプトを実行
chmod +x setup-selfhosted-runner.sh
sudo ./setup-selfhosted-runner.sh

# 2. GitHub にアクセスしてrunner登録
# https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/settings/actions/runners

# 3. "New self-hosted runner" をクリック
# 4. Linux x64 を選択
# 5. 表示されたコマンドを実行:
sudo -u actions-runner bash -c "cd /home/actions-runner/actions-runner && ./config.sh --url https://github.com/HirotakaKaminishi/mcp-cicd-pipeline --token YOUR_REGISTRATION_TOKEN --name mcp-server-runner --labels mcp-server,linux,x64,self-hosted --unattended"

# 6. サービスとして起動
sudo -u actions-runner bash -c "cd /home/actions-runner/actions-runner && ./svc.sh install actions-runner"
sudo -u actions-runner bash -c "cd /home/actions-runner/actions-runner && ./svc.sh start"
```

### 🔍 動作確認

**GitHub Actions ページで確認:**
```
https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions
```

**期待される表示:**
- 🟢 **self-hosted runner:** mcp-server-runner (Online)
- 🏷️ **Labels:** mcp-server, linux, x64, self-hosted

### 🚀 プロダクションデプロイの実行

**手動実行:**
```bash
# GitHub Actions タブ → "Production Deployment to MCP Server" → "Run workflow"
```

**自動実行:**
```bash
git push origin main  # mainブランチへのプッシュで自動実行
```

### 📊 デプロイワークフロー

1. **Test** - ESLint + Jest (ubuntu-latest)
2. **Build** - アプリケーションビルド (ubuntu-latest)  
3. **Deploy** - MPCサーバ実デプロイ (**self-hosted runner**)
4. **Notify** - デプロイ結果通知 (ubuntu-latest)

### ⚙️ Environment設定 (オプション)

**より厳密な本番環境管理のため:**

1. **Settings → Environments**
2. **New environment: "production"**
3. **Protection rules設定:**
   - Required reviewers: 1人
   - Deployment branches: main のみ

### 🔒 セキュリティ考慮事項

- **ネットワーク:** Self-hosted runnerがMPCサーバと同一ネットワーク
- **アクセス制御:** GitHub repository accessで管理
- **認証:** GitHub token + MCP APIキー
- **監査:** 全デプロイがGitHub Actionsログに記録

---

**🎯 設定完了後、GitHub ActionsからMPCサーバへの直接デプロイが可能になります！**
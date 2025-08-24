# 🚀 CI/CDパイプライン デプロイ手順

## ステップ1: GitHubリポジトリ作成

1. **GitHub (https://github.com) にアクセス**
2. **右上の「+」→「New repository」をクリック**
3. **以下の設定でリポジトリ作成:**
   ```
   Repository name: mcp-cicd-pipeline
   Description: MCP Server CI/CD Pipeline with GitHub Actions
   Visibility: Public または Private
   
   ⚠️ 重要: 以下のオプションは全て「チェックを外す」
   □ Add a README file
   □ Add .gitignore  
   □ Choose a license
   ```
4. **「Create repository」をクリック**

## ステップ2: リモートリポジトリ接続

作成後に表示されるリポジトリURLをコピーして、以下のコマンドを実行:

### Windows (Git Bash / PowerShell):
```bash
cd sample-project
git remote add origin https://github.com/[YOUR_USERNAME]/mcp-cicd-pipeline.git
git push -u origin main
```

### または自動スクリプト実行:
```bash
./deploy-setup.sh
```

## ステップ3: 自動CI/CD実行確認

プッシュ完了後、以下を確認:

1. **GitHub Actions確認**
   - リポジトリの「Actions」タブを開く
   - 「MCP Server CI/CD Pipeline」ワークフローが自動実行
   - Test → Build → Deploy → Notify の実行状況を確認

2. **MPCサーバ状態確認**
   ```bash
   node mcp-deploy.js status
   ```

3. **デプロイ結果確認**
   - デプロイログ: `/root/mcp_project/deployment.log`
   - アプリケーション: `http://192.168.111.200:3000`

## ステップ4: 継続的デプロイメント

### 日常の開発フロー:
```bash
# コード変更後
git add .
git commit -m "feature: 新機能追加"
git push origin main  # ← 自動CI/CD実行
```

### 緊急時対応:
```bash
# ロールバック
node mcp-deploy.js rollback

# 手動デプロイ
node mcp-deploy.js deploy
```

## 🎯 期待される結果

✅ **自動テスト実行** - Jest + ESLint  
✅ **自動ビルド** - npm build + アーティファクト生成  
✅ **自動デプロイ** - MPCサーバ経由リモートデプロイ  
✅ **ヘルスチェック** - デプロイ後の動作確認  
✅ **ログ記録** - 全工程の詳細ログ保存  

## 🔧 トラブルシューティング

### 認証エラー
```bash
# GitHub認証設定
gh auth login
# または
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### プッシュ失敗
```bash
# 強制プッシュ (初回のみ)
git push -f origin main
```

### MCP接続エラー
```bash
# MPC サーバ状態確認
curl http://192.168.111.200:8080
```

---

**🎉 完了後、フルオートメーション CI/CD パイプラインが稼働開始！**
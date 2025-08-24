# MCP Sample Application

MPCサーバとGitHub Actions統合CI/CDパイプライン用のサンプルアプリケーションです。

## 🚀 機能

- Express.js Webアプリケーション
- ヘルスチェックエンドポイント
- 自動テスト・リント・ビルド
- MCP APIデプロイメント統合

## 🛠️ セットアップ

```bash
# 依存関係インストール
npm install

# 開発サーバー起動
npm start

# テスト実行
npm test

# ビルド
npm run build
```

## 📡 エンドポイント

- `GET /` - メインページ
- `GET /health` - ヘルスチェック
- `GET /api/status` - API状態確認

## 🔄 CI/CD

### 自動デプロイ
```bash
git push origin main  # mainブランチで自動デプロイ
```

### 手動デプロイ
```bash
npm run deploy
```

## 📊 モニタリング

- アプリケーションログ: stdout
- デプロイログ: `/root/mcp_project/deployment.log`
- ヘルスチェック: `http://localhost:3000/health`

---

**MPCサーバ統合完了済み - 即座にデプロイ可能！**
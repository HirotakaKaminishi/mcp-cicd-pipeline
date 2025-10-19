# Vibe-Kanban Integration for MCP CI/CD Pipeline

## 📋 概要

このプロジェクトは、既存のMCP CI/CDパイプラインにVibe-Kanbanを統合するための実装です。AIコーディングエージェント（Claude Code、Gemini CLI、Amp）の管理と調整に特化したKanbanボードを提供します。

## 🏗️ アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    MCP CI/CD Pipeline                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ MCP Server  │  │    Nginx    │  │     React App       │ │
│  │   :8080     │  │ Proxy :80   │  │      :3000          │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         │                │                    │             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Docker Network (mcp-network)              │ │
│  │                  172.20.0.0/16                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│         │                                                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Vibe-Kanban                              │ │
│  │          AI Agent Orchestration                         │ │
│  │                  :3001                                  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 主要コンポーネント

### 1. Vibe-Kanban Integration Server (`server.js`)
- Express.jsベースのAPIサーバー
- MCP統合とClaude Code連携
- セキュリティミドルウェア
- GitHub webhook処理

### 2. MCP Server Adapter (`mcp-server-adapter.js`)
- Claude CodeとVibe-Kanbanの橋渡し
- タスク作成・更新・管理のMCPプロトコル実装
- リアルタイム進捗追跡

### 3. Security Middleware (`security/auth-middleware.js`)
- レート制限とアクセス制御
- AIエージェント並行実行制限
- エンタープライズセキュリティモード
- クリティカルパス保護

### 4. GitHub Integration (`github/integration.js`)
- 自動ブランチ作成とPR管理
- Webhook処理とCI/CD統合
- コード品質チェック

## 🚀 セットアップ手順

### 1. 環境変数の設定
```bash
# .envファイルをコピーして設定
cp .env.example .env
# 必要な環境変数を設定してください
```

### 2. Docker Composeでの起動
```bash
# すべてのサービスを起動（既存のMCP環境に追加）
docker-compose up -d vibe-kanban

# ログの確認
docker-compose logs -f vibe-kanban
```

### 3. 統合テストの実行
```bash
# 統合テストを実行
npm test

# または直接テストファイルを実行
node test/integration-test.js
```

## 📊 API エンドポイント

### Health Check
```bash
GET /health
```

### MCP Integration
```bash
GET /api/mcp/status          # MCP Server接続状態
```

### Kanban Management
```bash
GET    /api/kanban/tasks     # タスク一覧取得
POST   /api/kanban/tasks     # タスク作成
PATCH  /api/kanban/tasks/:id # タスク更新
GET    /api/kanban/agents/status # エージェント状態
```

### GitHub Integration
```bash
GET  /api/github/repository     # リポジトリ情報
GET  /api/github/pull-requests  # PR一覧
POST /api/github/create-branch  # ブランチ作成
POST /api/github/create-pr      # PR作成
POST /api/github/webhook        # GitHub Webhook受信
```

## 🔐 セキュリティ機能

### 1. レート制限
- API: 15分間に100リクエスト
- エージェント並行実行: 最大3つまで

### 2. アクセス制御
- クリティカルパス保護
- 人間承認が必要な操作の識別
- エンタープライズモード対応

### 3. 監査ログ
- すべてのAPIアクセスをログ記録
- セキュリティイベントの追跡
- 不審なアクティビティの検出

## 🎯 使用例

### Claude Codeでのタスク作成
```javascript
// MCP経由でタスクを作成
const task = await mcpServer.callTool('vibe_kanban_create_task', {
  title: 'ESLint errors in vite.config.js',
  description: 'Fix 7 ESLint errors found in the Vite configuration',
  category: 'refactoring',
  assignedAgent: 'claude-code',
  priority: 'high'
});
```

### GitHubとの自動連携
```javascript
// タスク完了時の自動PR作成
const pr = await github.createPullRequest({
  id: 'task-123',
  title: 'Fix ESLint errors',
  assignedAgent: 'claude-code',
  category: 'refactoring'
});
```

## 📈 監視と運用

### ヘルスチェック
```bash
curl http://localhost:3001/health
```

### メトリクス確認
```bash
# コンテナリソース使用量
docker stats vibe-kanban

# アプリケーションログ
docker-compose logs vibe-kanban
```

### トラブルシューティング
1. **MCP接続エラー**: MCP Serverの起動状態を確認
2. **GitHub統合エラー**: GITHUB_TOKENの設定確認
3. **パフォーマンス問題**: AI_AGENT_CONCURRENCY_LIMITの調整

## 🔄 CI/CD統合

### GitHub Actions統合
```yaml
# .github/workflows/docker-deploy.ymlに追加
- name: Test Vibe-Kanban Integration
  run: |
    docker-compose exec vibe-kanban npm test
```

### 自動デプロイメント
- PRマージ時の自動デプロイ
- ヘルスチェック付きゼロダウンタイムデプロイ
- ロールバック機能

## 📝 開発者向け情報

### ローカル開発
```bash
# 開発モード起動
npm run dev

# リント実行
npm run lint

# テスト実行
npm test
```

### 拡張方法
1. 新しいAIエージェントの追加
2. カスタムセキュリティルールの実装
3. 追加のGitHubイベント処理

## 🎉 導入完了

Vibe-Kanbanが正常に統合されると、以下が利用可能になります：

- ✅ AI エージェントの可視化と管理
- ✅ 自動タスク配布とスケジューリング
- ✅ GitHub との双方向連携
- ✅ リアルタイム進捗追跡
- ✅ セキュアな並行処理制御

## 🔗 関連リンク

- [Vibe-Kanban GitHub Repository](https://github.com/BloopAI/vibe-kanban)
- [MCP Protocol Documentation](https://docs.anthropic.com/mcp)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)

---

**🤖 AI-powered development with secure, scalable task orchestration**
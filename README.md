# MCP CI/CD Pipeline - React Monitoring Dashboard

[![React](https://img.shields.io/badge/React-19.1.1-61DAFB?logo=react)](https://reactjs.org/)
[![Vite](https://img.shields.io/badge/Vite-7.1.0-646CFF?logo=vite)](https://vitejs.dev/)
[![Docker](https://img.shields.io/badge/Docker-nginx:alpine-2496ED?logo=docker)](https://www.docker.com/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions)](https://github.com/features/actions)

## 📊 プロジェクト概要

エンタープライズレベルのReactアプリケーションで、完全自動化されたCI/CDパイプラインとMCPサーバー統合による分散デプロイメントを実装したシステム監視ダッシュボードです。

## 🏗️ 技術スタック

### フロントエンド
- **React** 19.1.1 - 最新版のReactフレームワーク
- **Vite** 7.1.0 - 高速ビルドツール
- **React Router DOM** 7.8.0 - SPAルーティング
- **Chart.js** 4.5.0 - データビジュアライゼーション

### テスト
- **Vitest** 3.2.4 - 高速ユニットテスト
- **Testing Library** - コンポーネントテスト
- **ESLint** 9.32.0 - コード品質管理

### インフラ・デプロイ
- **Docker** - コンテナ化
- **nginx:alpine** - Webサーバー
- **GitHub Actions** - CI/CDパイプライン
- **MCP Server** - リモートデプロイメント

## 📁 プロジェクト構造

```
sample-project-react/
├── src/                  # ソースコード (71KB)
│   ├── App.jsx          # メインアプリケーション
│   ├── pages/           # ページコンポーネント
│   │   ├── Dashboard.jsx    # システム監視ダッシュボード
│   │   ├── Health.jsx       # ヘルスチェックページ
│   │   └── ServiceLanding.jsx # サービス紹介ページ
│   └── assets/          # 静的資材
├── dist/                # ビルド済み資材 (461KB)
├── public/              # 公開資材 (4KB)
├── .github/             # CI/CD設定 (24KB)
│   └── workflows/
│       └── ci-cd.yml    # GitHubActions設定
├── Dockerfile           # Dockerコンテナ設定
├── vite.config.js       # Vite設定
└── package.json         # プロジェクト設定
```

## 🚀 CI/CDパイプライン

### ワークフロージョブ
1. **🧪 Test** - ESLint + Vitest実行
2. **🔨 Build** - 本番ビルド生成
3. **🚀 Deploy** - MCPサーバーへデプロイ
4. **🧪 Post-Deployment Tests** - デプロイ後検証
5. **🎯 Performance** - バンドルサイズチェック

### デプロイメント機能
- ✅ **ゼロダウンタイムデプロイ** - Blue-Greenデプロイメント
- ✅ **コンテナベース** - Docker による環境独立性
- ✅ **自動ロールバック** - エラー時の自動復旧
- ✅ **チャンク分割転送** - 大容量ファイル対応
- ✅ **自動クリーンアップ** - 古いイメージ・リリース削除

## 🌐 URLエンドポイント

### アプリケーション
- **ダッシュボード**: `http://192.168.111.200/dashboard`
- **ヘルスチェック**: `http://192.168.111.200/health`
- **サービスページ**: `http://192.168.111.200/service`

### API
- `/api/system` - システム情報
- `/api/health` - APIヘルスチェック
- `/api/resources` - リソース監視
- `/api/containers` - コンテナ状態
- `/api/server-stats` - サーバー統計

## 📈 パフォーマンス指標

| 項目 | サイズ/値 |
|-----|----------|
| **ビルドサイズ** | 461KB |
| **JavaScript** | 451KB |
| **CSS** | 11KB |
| **ビルド時間** | ~6秒 |
| **デプロイ時間** | ~2分30秒 |

## 🛠️ セットアップ

### 前提条件
- Node.js 20以上
- Docker
- Git

### インストール
```bash
# リポジトリのクローン
git clone https://github.com/HirotakaKaminishi/mcp-cicd-pipeline.git
cd sample-project-react

# 依存関係のインストール
npm install

# 開発サーバー起動
npm run dev
```

### ビルド
```bash
# 本番ビルド
npm run build

# ビルドプレビュー
npm run preview
```

### テスト
```bash
# ユニットテスト
npm test

# Lint実行
npm run lint
```

## 🐳 Docker実行

### ローカルビルド
```bash
# Dockerイメージビルド
docker build -t mcp-app .

# コンテナ起動
docker run -d -p 3000:3000 --name mcp-app mcp-app
```

### 本番環境
```bash
# MCP-APIコンテナと連携
docker network create mcp-network
docker run -d --name mcp-api --network mcp-network node:18-alpine
docker run -d --name mcp-app --network mcp-network -p 80:3000 mcp-app
```

## 📊 リソース使用状況

### MCPサーバー (2024年8月現在)
- **メモリ**: 3.6GB中 870MB使用 (24%)
- **ディスク**: 70GB中 4.8GB使用 (7%)
- **CPU**: 3.1% (低負荷)
- **コンテナ**: mcp-app (3.3MB), mcp-api (31.8MB)

## 📝 最近の更新履歴

| バージョン | 内容 |
|-----------|------|
| 2.0.2 | ルーティング改善、ヘルスページ修正 |
| 2.0.1 | nginx設定修正、APIプロキシ追加 |
| 2.0.0 | React 19へアップグレード |

## 🔧 設定ファイル

### nginx設定の要点
```nginx
location /dashboard { try_files $uri $uri/ /index.html; }
location /health { try_files $uri $uri/ /index.html; }
location /service { try_files $uri $uri/ /index.html; }
location /api/ { proxy_pass http://mcp-api:3000/api/; }
```

### GitHub Actions環境変数
- `DEPLOY_URL`: デプロイ先URL
- `MCP_SERVER_URL`: MCPサーバーURL
- `DEPLOY_PATH`: デプロイパス

## 🤝 コントリビューション

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/AmazingFeature`)
3. 変更をコミット (`git commit -m 'Add some AmazingFeature'`)
4. ブランチにプッシュ (`git push origin feature/AmazingFeature`)
5. プルリクエストを作成

## 📄 ライセンス

このプロジェクトはプライベートプロジェクトです。

## 👥 作成者

- **Hirotaka Kaminishi** - [GitHub](https://github.com/HirotakaKaminishi)
- **Claude** - AI Assistant

## 🙏 謝辞

- React Team
- Vite Team
- GitHub Actions
- Docker Community

## 📋 デプロイメント履歴

✅ Fixed nginx configuration issue in post-deployment tests (2025-08-11)

---

🤖 Generated with [Claude Code](https://claude.ai/code)

最終更新: 2024年8月12日

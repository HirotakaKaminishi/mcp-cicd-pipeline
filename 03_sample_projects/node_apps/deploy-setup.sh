#!/bin/bash

# MCP CI/CD Pipeline - GitHub Setup Script

echo "🚀 MCP CI/CD Pipeline GitHub Setup"
echo "=================================="

# リポジトリURL入力
echo ""
echo "GitHub でリポジトリを作成後、以下の手順を実行してください:"
echo ""
echo "1. GitHubでリポジトリ作成:"
echo "   - Repository name: mcp-cicd-pipeline"  
echo "   - Description: MCP Server CI/CD Pipeline with GitHub Actions"
echo "   - Public または Private"
echo "   - README, .gitignore, license は追加しない"
echo ""

read -p "作成したリポジトリのURL (https://github.com/username/repo-name.git): " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "❌ リポジトリURLが入力されていません"
    exit 1
fi

echo ""
echo "🔗 リモートリポジトリを追加..."
git remote add origin "$REPO_URL"

if [ $? -ne 0 ]; then
    echo "⚠️ リモートが既に存在します。上書きします..."
    git remote set-url origin "$REPO_URL"
fi

echo "✅ リモートリポジトリ追加完了"

echo ""
echo "📤 初回プッシュを実行..."
git push -u origin main

if [ $? -eq 0 ]; then
    echo "✅ プッシュ完了!"
    echo ""
    echo "🎉 GitHub Actions CI/CD パイプラインが起動します!"
    echo ""
    echo "📊 確認方法:"
    echo "1. GitHub リポジトリの 'Actions' タブを確認"
    echo "2. パイプライン実行状況をリアルタイム監視"
    echo "3. デプロイ完了後、MPC サーバ状態を確認"
    echo ""
    echo "🔧 コマンド例:"
    echo "   git push origin main          # 自動CI/CD実行"  
    echo "   node mcp-deploy.js status     # MPC サーバ状態確認"
    echo "   node mcp-deploy.js deploy     # 手動デプロイ"
    echo ""
    echo "🌐 リポジトリURL: $REPO_URL"
else
    echo "❌ プッシュに失敗しました"
    echo "認証設定やネットワーク接続を確認してください"
    exit 1
fi
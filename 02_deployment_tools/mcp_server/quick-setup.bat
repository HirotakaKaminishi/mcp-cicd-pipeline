@echo off
echo =================================
echo MCP CI/CD Pipeline Quick Setup
echo =================================
echo.

echo GitHubリポジトリ作成後、以下のコマンドを実行してください：
echo.
echo cd sample-project
echo git remote add origin https://github.com/HirotakaKaminishi/mcp-cicd-pipeline.git
echo git push -u origin main
echo.

echo リポジトリURL準備完了後、Enterを押してください...
pause > nul

cd sample-project

echo.
echo 🔗 リモートリポジトリを追加中...
git remote add origin https://github.com/HirotakaKaminishi/mcp-cicd-pipeline.git

if %errorlevel% neq 0 (
    echo ⚠️ リモートが既に存在します。更新中...
    git remote set-url origin https://github.com/HirotakaKaminishi/mcp-cicd-pipeline.git
)

echo ✅ リモートリポジトリ設定完了

echo.
echo 📤 初回プッシュを実行中...
git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo 🎉 プッシュ成功！GitHub Actions CI/CD パイプラインが起動します！
    echo.
    echo 📊 確認方法：
    echo 1. https://github.com/HirotakaKaminishi/mcp-cicd-pipeline/actions
    echo 2. パイプライン実行状況をリアルタイム監視
    echo 3. Test → Build → Deploy → Notify の自動実行
    echo.
    echo 🌐 リポジトリ: https://github.com/HirotakaKaminishi/mcp-cicd-pipeline
    echo.
) else (
    echo ❌ プッシュに失敗しました
    echo 認証設定を確認してください
    echo.
    echo 🔧 認証方法：
    echo 1. Personal Access Token使用
    echo 2. SSH Key設定
    echo 3. Git Credential Manager
)

echo.
pause
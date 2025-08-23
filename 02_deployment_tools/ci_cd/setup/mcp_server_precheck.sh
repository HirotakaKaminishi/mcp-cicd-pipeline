#!/bin/bash
# MCPサーバ事前チェックスクリプト
# 構築スクリプト実行前に、このスクリプトでサーバの状態を確認してください
#
# 使用方法:
# 1. MCPサーバにコピー: scp mcp_server_precheck.sh user@server:/tmp/
# 2. 実行: ssh user@server "bash /tmp/mcp_server_precheck.sh"

echo "========================================="
echo "MCPサーバ 事前チェックスクリプト"
echo "実行時刻: $(date)"
echo "========================================="

# チェック結果を格納する変数
WARNINGS=0
ERRORS=0

# 色付き出力用の関数
print_ok() { echo -e "\033[32m✓\033[0m $1"; }
print_warn() { echo -e "\033[33m⚠\033[0m $1"; WARNINGS=$((WARNINGS+1)); }
print_error() { echo -e "\033[31m✗\033[0m $1"; ERRORS=$((ERRORS+1)); }
print_info() { echo -e "\033[36mℹ\033[0m $1"; }

# 1. システム基本情報
echo -e "\n[1/8] システム基本情報確認"
echo "----------------------------------------"
print_info "ホスト名: $(hostname)"
print_info "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
print_info "カーネル: $(uname -r)"
print_info "アーキテクチャ: $(uname -m)"
print_info "稼働時間: $(uptime -p)"

# 2. ユーザー権限確認
echo -e "\n[2/8] ユーザー権限確認"
echo "----------------------------------------"
if [ "$EUID" -eq 0 ]; then
    print_warn "rootユーザーで実行しています"
else
    print_ok "一般ユーザー: $(whoami)"
fi

# sudo権限確認
if sudo -n true 2>/dev/null; then
    print_ok "sudo権限: 利用可能（パスワードなし）"
elif sudo -v 2>/dev/null; then
    print_ok "sudo権限: 利用可能（パスワード必要）"
else
    print_error "sudo権限: 利用不可"
fi

# 3. ディスク容量確認
echo -e "\n[3/8] ディスク容量確認"
echo "----------------------------------------"
df -h | grep -E '^/dev/' | while read line; do
    USAGE=$(echo $line | awk '{print $5}' | sed 's/%//')
    MOUNT=$(echo $line | awk '{print $6}')
    AVAIL=$(echo $line | awk '{print $4}')
    
    if [ "$USAGE" -gt 90 ]; then
        print_error "$MOUNT: 使用率 $USAGE% (空き: $AVAIL)"
    elif [ "$USAGE" -gt 70 ]; then
        print_warn "$MOUNT: 使用率 $USAGE% (空き: $AVAIL)"
    else
        print_ok "$MOUNT: 使用率 $USAGE% (空き: $AVAIL)"
    fi
done

# ホームディレクトリの空き容量
HOME_AVAIL=$(df -h ~ | tail -1 | awk '{print $4}')
print_info "ホームディレクトリ空き容量: $HOME_AVAIL"

# 4. メモリ状況確認
echo -e "\n[4/8] メモリ状況確認"
echo "----------------------------------------"
TOTAL_MEM=$(free -h | grep "^Mem:" | awk '{print $2}')
USED_MEM=$(free -h | grep "^Mem:" | awk '{print $3}')
AVAIL_MEM=$(free -h | grep "^Mem:" | awk '{print $7}')
MEM_PERCENT=$(free | grep "^Mem:" | awk '{printf "%.0f", $3/$2 * 100}')

print_info "総メモリ: $TOTAL_MEM"
print_info "使用中: $USED_MEM"
print_info "利用可能: $AVAIL_MEM"

if [ "$MEM_PERCENT" -gt 90 ]; then
    print_error "メモリ使用率: $MEM_PERCENT%"
elif [ "$MEM_PERCENT" -gt 70 ]; then
    print_warn "メモリ使用率: $MEM_PERCENT%"
else
    print_ok "メモリ使用率: $MEM_PERCENT%"
fi

# 5. Python環境確認
echo -e "\n[5/8] Python環境確認"
echo "----------------------------------------"

# Python3確認
if command -v python3 &> /dev/null; then
    PY_VERSION=$(python3 --version 2>&1)
    print_ok "Python3: $PY_VERSION"
else
    print_error "Python3: インストールされていません"
fi

# pip確認
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version 2>&1 | head -1)
    print_ok "pip3: インストール済み"
else
    print_warn "pip3: インストールされていません"
fi

# 既存の仮想環境確認
if [ -d "$HOME/mcp_env" ]; then
    print_warn "既存の仮想環境が存在: ~/mcp_env"
else
    print_info "仮想環境: 未作成"
fi

# 6. 必要なツール確認
echo -e "\n[6/8] 必要なツール確認"
echo "----------------------------------------"

TOOLS=("git" "wget" "curl" "vim" "yum")
for tool in "${TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        print_ok "$tool: インストール済み"
    else
        print_warn "$tool: インストールされていません"
    fi
done

# 7. 既存プロジェクト確認
echo -e "\n[7/8] 既存プロジェクト確認"
echo "----------------------------------------"

if [ -d "$HOME/mcp_project" ]; then
    print_warn "既存プロジェクトディレクトリが存在: ~/mcp_project"
    echo "  内容:"
    ls -la "$HOME/mcp_project" 2>/dev/null | head -5
else
    print_info "プロジェクトディレクトリ: 未作成"
fi

# 8. ネットワーク接続確認
echo -e "\n[8/8] ネットワーク接続確認"
echo "----------------------------------------"

# DNSレゾリューション確認
if ping -c 1 -W 2 google.com &> /dev/null; then
    print_ok "インターネット接続: 正常"
else
    print_error "インターネット接続: 失敗"
fi

# パッケージリポジトリ確認
if yum repolist &> /dev/null; then
    REPO_COUNT=$(yum repolist 2>/dev/null | grep -c "enabled")
    print_ok "Yumリポジトリ: $REPO_COUNT 個有効"
else
    print_error "Yumリポジトリ: アクセスできません"
fi

# 結果サマリー
echo -e "\n========================================="
echo "チェック結果サマリー"
echo "========================================="

if [ $ERRORS -gt 0 ]; then
    echo -e "\033[31m✗ エラー: $ERRORS 件\033[0m"
    echo "  構築スクリプト実行前に問題を解決してください"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "\033[33m⚠ 警告: $WARNINGS 件\033[0m"
    echo "  既存環境との競合に注意してください"
fi

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "\033[32m✓ すべてのチェック項目をクリア\033[0m"
    echo "  構築スクリプトを安全に実行できます"
elif [ $ERRORS -eq 0 ]; then
    echo -e "\033[33m△ 警告はありますが実行可能です\033[0m"
else
    echo -e "\033[31m× エラーを解決してから実行してください\033[0m"
fi

echo ""
echo "次のステップ:"
if [ $ERRORS -eq 0 ]; then
    echo "1. 構築スクリプトを実行:"
    echo "   bash /tmp/mcp_remote_setup_script.sh"
else
    echo "1. 上記のエラーを解決"
    echo "2. このチェックスクリプトを再実行"
    echo "3. エラーがなくなったら構築スクリプトを実行"
fi
echo "========================================="
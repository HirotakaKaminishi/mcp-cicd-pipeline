#!/bin/bash
# SSH接続スクリプト for 192.168.111.163

# 変数定義
TARGET_IP="192.168.111.163"
SSH_KEY="C:/Users/hirotaka/Documents/work/auth/pc_investigation_key"
USERNAME="pc"  # 対象マシンのユーザー名（要確認）

echo "=== PC Investigation SSH Connection ==="
echo "Target: $TARGET_IP"
echo "Key: $SSH_KEY"
echo "User: $USERNAME"
echo ""

# SSH接続テスト
echo "Testing SSH connection..."
ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$USERNAME@$TARGET_IP" "echo 'SSH connection successful!'"

if [ $? -eq 0 ]; then
    echo "✅ SSH connection established!"
    echo "You can now connect with:"
    echo "ssh -i \"$SSH_KEY\" $USERNAME@$TARGET_IP"
else
    echo "❌ SSH connection failed. Check:"
    echo "1. Target machine is powered on"
    echo "2. SSH server is running"
    echo "3. Firewall allows port 22"
    echo "4. Public key is properly installed"
fi
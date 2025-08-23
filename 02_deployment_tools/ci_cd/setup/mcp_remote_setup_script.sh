#!/bin/bash
# MCPサーバ構築スクリプト（手動実行用）
# このスクリプトをMCPサーバにコピーして実行してください
# 
# 使用方法:
# 1. このファイルをMCPサーバにコピー: scp mcp_remote_setup_script.sh user@server:/tmp/
# 2. SSH接続: ssh user@server
# 3. 実行: bash /tmp/mcp_remote_setup_script.sh

set -e  # エラー時に停止

echo "========================================="
echo "MCPサーバ環境構築スクリプト"
echo "実行時刻: $(date)"
echo "ホスト名: $(hostname)"
echo "========================================="

# 1. システム情報確認
echo -e "\n[1/6] システム情報確認..."
uname -a
cat /etc/os-release

# 2. 必要なパッケージのインストール
echo -e "\n[2/6] 必要なパッケージをインストール..."
sudo yum update -y
sudo yum install -y \
    python3 \
    python3-pip \
    git \
    vim \
    wget \
    curl \
    net-tools \
    htop

# 3. Python環境セットアップ
echo -e "\n[3/6] Python環境をセットアップ..."
python3 --version
pip3 --version

# 仮想環境作成
python3 -m venv ~/mcp_env
source ~/mcp_env/bin/activate

# 必要なPythonパッケージインストール
pip install --upgrade pip
pip install \
    jupyterlab \
    numpy \
    pandas \
    matplotlib \
    requests

# 4. プロジェクトディレクトリ作成
echo -e "\n[4/6] プロジェクトディレクトリを作成..."
mkdir -p ~/mcp_project/{src,tests,docs,data}
cd ~/mcp_project

# 5. サンプルコード作成
echo -e "\n[5/6] サンプルコードを作成..."
cat > ~/mcp_project/src/hello_mcp.py << 'EOF'
#!/usr/bin/env python3
"""
MCPサーバ上で実行するサンプルスクリプト
"""
import sys
import platform
import datetime

def main():
    print("=" * 50)
    print("MCPサーバ - Hello World!")
    print("=" * 50)
    print(f"実行時刻: {datetime.datetime.now()}")
    print(f"Python: {sys.version}")
    print(f"Platform: {platform.platform()}")
    print(f"Architecture: {platform.architecture()}")
    print("=" * 50)

if __name__ == "__main__":
    main()
EOF

# テストコード作成
cat > ~/mcp_project/tests/test_basic.py << 'EOF'
#!/usr/bin/env python3
"""
基本的なテストコード
"""
import unittest
import sys
import os

# srcディレクトリをパスに追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

class TestBasic(unittest.TestCase):
    def test_import(self):
        """モジュールのインポートテスト"""
        try:
            import hello_mcp
            self.assertTrue(True)
        except ImportError:
            self.fail("hello_mcpモジュールのインポートに失敗")
    
    def test_system(self):
        """システム環境テスト"""
        import platform
        self.assertIsNotNone(platform.system())
        self.assertIsNotNone(platform.version())

if __name__ == "__main__":
    unittest.main()
EOF

# 6. Jupyter設定（オプション）
echo -e "\n[6/6] Jupyter Lab設定..."
jupyter lab --generate-config 2>/dev/null || true

# Jupyter起動スクリプト作成
cat > ~/mcp_project/start_jupyter.sh << 'EOF'
#!/bin/bash
source ~/mcp_env/bin/activate
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser
EOF
chmod +x ~/mcp_project/start_jupyter.sh

# 完了メッセージ
echo -e "\n========================================="
echo "構築完了！"
echo "========================================="
echo "プロジェクトディレクトリ: ~/mcp_project"
echo ""
echo "次のステップ:"
echo "1. サンプルコード実行:"
echo "   cd ~/mcp_project"
echo "   source ~/mcp_env/bin/activate"
echo "   python src/hello_mcp.py"
echo ""
echo "2. テスト実行:"
echo "   python tests/test_basic.py"
echo ""
echo "3. Jupyter Lab起動（オプション）:"
echo "   ./start_jupyter.sh"
echo "========================================="

# 環境変数設定を.bashrcに追加
echo "" >> ~/.bashrc
echo "# MCP Project Environment" >> ~/.bashrc
echo "alias mcp_activate='source ~/mcp_env/bin/activate'" >> ~/.bashrc
echo "alias mcp_project='cd ~/mcp_project'" >> ~/.bashrc

echo -e "\nエイリアスを追加しました:"
echo "  mcp_activate - Python仮想環境を有効化"
echo "  mcp_project  - プロジェクトディレクトリに移動"
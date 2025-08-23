# Claude Code自動実行エイリアス
# 使用例: cc "ファイルを作成して"
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$joinedArgs = $Arguments -join ' '
claude --dangerously-skip-permissions $joinedArgs
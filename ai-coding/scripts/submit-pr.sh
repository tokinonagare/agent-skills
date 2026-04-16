#!/bin/bash
# 阶段 2.3: 提交与 PR (Submit & PR)

# 1. 提交代码
echo "📤 提交代码..."
git add .
# 提示：实际 commit 信息应由 AI 根据改动生成，此处仅为结构示例
# git commit -m "feat: 实现 xxx"

# 2. 检查或创建 PR
echo "🔍 检查 PR 状态..."
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
MAIN_BRANCH=${MAIN_BRANCH:-"master"}
EXISTING_PR=$(gh pr view --json url,number -q '.url')

if [ -n "$EXISTING_PR" ]; then
    echo "✅ 发现现有 PR: $EXISTING_PR"
    PR_URL="$EXISTING_PR"
    PR_NUMBER=$(gh pr view --json number -q .number)
else
    echo "📤 创建新 PR..."
    # 提示：标题和描述应由 AI 生成
    # gh pr create --title "feat: xxx" --body "..." --base "$MAIN_BRANCH"
    PR_URL=$(gh pr view --json url -q .url)
    PR_NUMBER=$(gh pr view --json number -q .number)
fi

# 3. 更新 iTerm2 session 名称 (可选)
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
SESSION_NAME="${REPO_NAME}-pr${PR_NUMBER}"
echo "🏷️ 更新 iTerm2 session 名称为: $SESSION_NAME"
python3 -c "
try:
    import iterm2
    async def main(connection):
        app = await iterm2.async_get_app(connection)
        tab = app.current_terminal_window.current_tab
        session = tab.current_session
        await session.async_set_name('$SESSION_NAME')
        await tab.async_set_title('$SESSION_NAME')
    iterm2.run_until_complete(main)
except:
    pass
" 2>/dev/null

echo "✅ PR 已就绪: $PR_URL"
echo "STATUS: PR_READY"
echo "PR_NUMBER: $PR_NUMBER"

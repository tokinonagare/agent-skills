#!/bin/bash
# 阶段 3: 持续监控与自动修复 (The Monitor Loop)

MONITOR_CYCLE=0
PR_NUMBER=$(gh pr view --json number -q .number)
PR_URL=$(gh pr view --json url -q .url)

echo "✅ PR 已就绪：$PR_URL"
echo "🔍 启动自动监控守护进程..."

LAST_COMMENT_ID=""
LAST_REVIEW_ID=""

while true; do
    MONITOR_CYCLE=$((MONITOR_CYCLE + 1))
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 监控周期 #$MONITOR_CYCLE - $(date '+%H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 1. 检查 PR 状态
    PR_INFO=$(gh pr view $PR_NUMBER --json state,url --jq '.state + "|" + .url')
    PR_STATE=$(echo "$PR_INFO" | cut -d'|' -f1)
    
    if [ "$PR_STATE" = "MERGED" ] || [ "$PR_STATE" = "CLOSED" ]; then
        echo "🎉 PR 已$PR_STATE，监控结束。"
        rm -rf DEVELOPMENT
        echo "STATUS: FINISHED"
        break
    fi

    # 2. 检查 Review Threads (GraphQL)
    OWNER_REPO=$(echo "$PR_URL" | sed -E 's#https://github.com/##; s#/pull/.*##')
    OWNER=$(echo "$OWNER_REPO" | cut -d'/' -f1)
    REPO=$(echo "$OWNER_REPO" | cut -d'/' -f2)

    UNRESOLVED_THREADS=$(gh api graphql -f query="
        query {
          repository(owner: \"$OWNER\", name: \"$REPO\") {
            pullRequest(number: $PR_NUMBER) {
              reviewThreads(first: 50) {
                nodes {
                  id
                  isResolved
                  comments(first: 5) {
                    nodes {
                      author { login }
                      body
                    }
                  }
                }
              }
            }
          }
        }" --jq '.data.repository.pullRequest.reviewThreads.nodes | map(select(.isResolved == false))')

    UNRESOLVED_COUNT=$(echo "$UNRESOLVED_THREADS" | jq 'length')
    if [ "$UNRESOLVED_COUNT" -gt 0 ]; then
        echo "📋 发现 $UNRESOLVED_COUNT 个未解决的 Review Threads"
        echo "STATUS: NEED_REFIX_REVIEW"
        # 此时 AI 应退出脚本执行，处理完代码后再次启动监控
        exit 0
    fi

    # 3. 检查 CI 状态
    FAILED_CHECK=$(gh pr checks $PR_NUMBER --json name,conclusion --jq '.[] | select(.conclusion=="FAILURE") | .name' | head -n 1)
    if [ -n "$FAILED_CHECK" ]; then
        echo "❌ 发现 CI 失败: $FAILED_CHECK"
        echo "STATUS: CI_FAILED"
        exit 0
    fi

    # 4. 检查冲突
    IS_CONFLICT=$(gh pr view $PR_NUMBER --json mergeable -q .mergeable)
    if [ "$IS_CONFLICT" = "CONFLICTING" ]; then
        echo "⚔️ 检测到代码冲突"
        echo "STATUS: CONFLICT_DETECTED"
        exit 0
    fi

    echo "⏳ 无新事件，等待 60 秒..."
    sleep 60
done

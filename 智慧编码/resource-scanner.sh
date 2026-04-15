#!/bin/bash
# 资源文件扫描与清理脚本
# 用于智慧编码 Skill 的阶段 2.2
# 功能：检测并清理未使用的新增资源文件

set -e

echo "🔍 智慧编码 - 资源文件扫描与清理"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. 定义资源文件扩展名
RESOURCE_EXTENSIONS="png|jpg|jpeg|gif|svg|webp|ico|avif|woff|woff2|ttf|otf|eot|mp4|mp3|webm|ogg|wav|pdf"

# 2. 定义代码文件扩展名（用于搜索引用）
CODE_EXTENSIONS="js|ts|jsx|tsx|vue|svelte|css|scss|sass|less|styl|html|md|mdx|json|yaml|yml"

# 3. 检测新增的资源文件（已暂存）
echo "📦 检测新增的资源文件..."
NEW_RESOURCES=$(git diff --cached --name-only --diff-filter=A | grep -E "\.(${RESOURCE_EXTENSIONS})$" || true)

if [ -z "$NEW_RESOURCES" ]; then
    echo "ℹ️  没有新增资源文件，跳过扫描"
    exit 0
fi

TOTAL_COUNT=$(echo "$NEW_RESOURCES" | wc -l | tr -d ' ')
echo "📊 发现 $TOTAL_COUNT 个新增资源文件"
echo ""

# 4. 获取所有代码文件列表（用于搜索引用）
echo "📝 准备代码文件索引..."
CODE_FILES=$(git ls-files | grep -E "\.(${CODE_EXTENSIONS})$" || true)

if [ -z "$CODE_FILES" ]; then
    echo "⚠️  警告：没有找到代码文件，无法检查引用"
    exit 0
fi

CODE_FILE_COUNT=$(echo "$CODE_FILES" | wc -l | tr -d ' ')
echo "📚 将在 $CODE_FILE_COUNT 个代码文件中搜索引用"
echo ""

# 5. 逐个检查资源文件是否被引用
UNUSED_FILES=()
USED_FILES=()

while IFS= read -r file; do
    [ -z "$file" ] && continue

    FILENAME=$(basename "$file")
    FILENAME_NO_EXT="${FILENAME%.*}"

    echo "🔎 检查: $file"

    # 构建搜索模式
    # 1. 完整文件名
    # 2. 文件路径
    # 3. 不带扩展名的文件名（用于 import 语句）
    FOUND=false

    # 搜索文件名和路径
    if echo "$CODE_FILES" | xargs grep -l -F -e "$FILENAME" -e "$file" 2>/dev/null | grep -q .; then
        FOUND=true
    fi

    # 如果还没找到，尝试搜索不带扩展名的名称（常见于 import 和 require）
    if [ "$FOUND" = false ]; then
        if echo "$CODE_FILES" | xargs grep -l -E "(['\"\`/]$FILENAME_NO_EXT['\"\`)]|import.*$FILENAME_NO_EXT)" 2>/dev/null | grep -q .; then
            FOUND=true
        fi
    fi

    if [ "$FOUND" = true ]; then
        echo "  ✅ 已使用"
        USED_FILES+=("$file")
    else
        echo "  ⚠️  未使用"
        UNUSED_FILES+=("$file")
    fi
    echo ""
done <<< "$NEW_RESOURCES"

# 6. 输出统计结果
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 扫描结果统计："
echo "   总计: $TOTAL_COUNT 个文件"
echo "   已使用: ${#USED_FILES[@]} 个文件"
echo "   未使用: ${#UNUSED_FILES[@]} 个文件"
echo ""

# 7. 清理未使用的文件
if [ ${#UNUSED_FILES[@]} -gt 0 ]; then
    echo "🗑️  清理未使用的资源文件："
    for file in "${UNUSED_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            echo "  ✅ 已删除: $file"
        fi
    done

    # 更新 git 暂存区（移除已删除的文件）
    git add -u

    echo ""
    echo "✅ 资源文件清理完成"
else
    echo "✅ 所有新增资源文件都已被使用，无需清理"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

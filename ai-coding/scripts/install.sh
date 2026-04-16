#!/bin/zsh

###############################################
# AI Coding Skill 安装脚本
# 将 Skill 链接到本地 AI 助手配置目录
###############################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_NAME="ai-coding"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
TARGET_DIR="$CLAUDE_SKILLS_DIR/$SKILL_NAME"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

main() {
    log_info "========================================="
    log_info "开始安装 $SKILL_NAME Skill"
    log_info "========================================="

    # 1. 检查配置目录 (默认为 Claude)
    if [ ! -d "$CLAUDE_SKILLS_DIR" ]; then
        log_info "创建 skills 目录: $CLAUDE_SKILLS_DIR"
        mkdir -p "$CLAUDE_SKILLS_DIR"
    fi

    # 2. 检查是否已安装
    if [ -L "$TARGET_DIR" ]; then
        log_warning "Skill 已安装，正在更新链接..."
        rm "$TARGET_DIR"
    elif [ -d "$TARGET_DIR" ]; then
        log_warning "发现同名目录，正在备份..."
        mv "$TARGET_DIR" "${TARGET_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # 3. 创建符号链接
    log_info "创建符号链接..."
    ln -s "$ROOT_DIR" "$TARGET_DIR"

    if [ $? -eq 0 ]; then
        log_success "✅ Skill 安装成功！"
    else
        log_error "❌ Skill 安装失败"
        exit 1
    fi

    # 4. 验证关键文件
    log_info "验证关键文件..."
    files_to_check=(
        "$ROOT_DIR/SKILL.md"
        "$ROOT_DIR/templates/config.example.json"
        "$ROOT_DIR/scripts/init-project.sh"
    )
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            log_success "✅ 找到: $(basename "$file")"
        else
            log_error "❌ 缺失: $file"
            exit 1
        fi
    done

    echo ""
    log_success "🎉 $SKILL_NAME Skill 安装完成！"
    log_info "用法：进入项目根目录运行 $TARGET_DIR/scripts/init-project.sh"
    echo ""
}

main "$@"

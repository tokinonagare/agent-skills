#!/bin/zsh

###############################################
# AI Coding - 项目初始化脚本
# 在项目根目录创建 DEVELOPMENT 文件夹并初始化配置
###############################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Skill 路径 (根据 install.sh 的默认位置)
SKILL_DIR="$HOME/.claude/skills/ai-coding"
AUTO_YES=false

# 解析参数
for arg in "$@"; do
    case $arg in
        --yes|-y) AUTO_YES=true; shift ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

main() {
    log_info "========================================="
    log_info "AI Coding - 项目初始化"
    log_info "========================================="

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "当前目录不是 Git 仓库"
        exit 1
    fi

    PROJECT_ROOT=$(git rev-parse --show-toplevel)
    DEVELOPMENT_DIR="$PROJECT_ROOT/DEVELOPMENT"

    if [ ! -d "$DEVELOPMENT_DIR" ]; then
        mkdir -p "$DEVELOPMENT_DIR"
        log_success "✅ 创建 DEVELOPMENT 目录"
    fi

    # 复制模板
    templates=(
        "templates/config.example.json:config.json"
        "templates/requirements.example.md:requirements.md"
    )

    for item in "${templates[@]}"; do
        src="${item%%:*}"
        dst="${item#*:}"
        if [ ! -f "$DEVELOPMENT_DIR/$dst" ]; then
            cp "$SKILL_DIR/$src" "$DEVELOPMENT_DIR/$dst"
            log_success "✅ 初始化 $dst"
        fi
    done

    # 检查 .gitignore
    GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"
    if [ -f "$GITIGNORE_FILE" ] && ! grep -q "DEVELOPMENT" "$GITIGNORE_FILE"; then
        echo -e "\n# AI Coding\nDEVELOPMENT/" >> "$GITIGNORE_FILE"
        log_success "✅ 已添加 DEVELOPMENT 到 .gitignore"
    fi

    log_success "🎉 项目初始化完成！"
}

main "$@"

#!/bin/zsh

###############################################
# 智慧编码 - 项目初始化脚本
# 在项目根目录创建 DEVELOPMENT 文件夹并初始化配置
#
# 用法:
#   ./init-project.sh          # 交互模式
#   ./init-project.sh --yes    # 非交互模式（自动确认所有操作）
###############################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Skill 模板目录
SKILL_DIR="$HOME/.claude/skills/智慧编码"

# 非交互模式标志
AUTO_YES=false

# 解析参数
for arg in "$@"; do
    case $arg in
        --yes|-y)
            AUTO_YES=true
            shift
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --yes, -y    非交互模式，自动确认所有操作"
            echo "  --help, -h   显示此帮助信息"
            exit 0
            ;;
    esac
done

###############################################
# 日志函数
###############################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

###############################################
# 主流程
###############################################

main() {
    log_info "========================================="
    log_info "智慧编码 - 项目初始化"
    log_info "========================================="

    # 1. 检查是否在 Git 仓库中
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "当前目录不是 Git 仓库"
        log_info "请在项目根目录运行此脚本"
        exit 1
    fi

    # 2. 获取项目根目录
    PROJECT_ROOT=$(git rev-parse --show-toplevel)
    log_info "项目根目录: $PROJECT_ROOT"

    # 3. 检查 Skill 是否已安装
    if [ ! -d "$SKILL_DIR" ]; then
        log_error "未找到智慧编码 Skill"
        log_info "请先安装 Skill："
        log_info "  cd /path/to/auto_coding/skills/智慧编码"
        log_info "  ./install.sh"
        exit 1
    fi

    # 4. 创建 DEVELOPMENT 目录
    DEVELOPMENT_DIR="$PROJECT_ROOT/DEVELOPMENT"

    if [ ! -d "$DEVELOPMENT_DIR" ]; then
        log_info "创建 DEVELOPMENT 目录..."
        mkdir -p "$DEVELOPMENT_DIR"
        log_success "✅ DEVELOPMENT 目录创建成功"
    else
        log_info "DEVELOPMENT 目录已存在"
    fi

    # 5. 复制配置文件模板（仅当两者都存在时才询问是否覆盖）
    SHOULD_OVERWRITE=false

    if [ -f "$DEVELOPMENT_DIR/config.json" ] && [ -f "$DEVELOPMENT_DIR/requirements.md" ]; then
        log_warning "发现现有配置文件（config.json 和 requirements.md），是否覆盖？"

        if [ "$AUTO_YES" = true ]; then
            log_info "非交互模式：自动覆盖现有文件"
            SHOULD_OVERWRITE=true
        else
            echo -n "输入 'yes' 覆盖，其他键保留现有文件并补齐缺失文件: "
            read -r response

            if [ "$response" = "yes" ]; then
                SHOULD_OVERWRITE=true
            else
                log_info "保留现有配置文件"
            fi
        fi
    fi

    # 复制或补齐配置文件
    log_info "检查并复制配置文件模板..."

    # 处理 config.json
    if [ ! -f "$SKILL_DIR/config.example.json" ]; then
        log_error "未找到 config.example.json 模板"
        exit 1
    fi

    if [ ! -f "$DEVELOPMENT_DIR/config.json" ] || [ "$SHOULD_OVERWRITE" = true ]; then
        cp "$SKILL_DIR/config.example.json" "$DEVELOPMENT_DIR/config.json"
        if [ "$SHOULD_OVERWRITE" = true ]; then
            log_success "✅ config.json 已覆盖"
        else
            log_success "✅ config.json 创建成功"
        fi
    else
        log_info "ℹ️  保留现有 config.json"
    fi

    # 处理 requirements.md
    if [ ! -f "$SKILL_DIR/requirements.example.md" ]; then
        log_error "未找到 requirements.example.md 模板"
        exit 1
    fi

    if [ ! -f "$DEVELOPMENT_DIR/requirements.md" ] || [ "$SHOULD_OVERWRITE" = true ]; then
        cp "$SKILL_DIR/requirements.example.md" "$DEVELOPMENT_DIR/requirements.md"
        if [ "$SHOULD_OVERWRITE" = true ]; then
            log_success "✅ requirements.md 已覆盖"
        else
            log_success "✅ requirements.md 创建成功"
        fi
    else
        log_info "ℹ️  保留现有 requirements.md"
    fi

    # 6. 检查 .gitignore
    GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"

    log_info "检查 .gitignore 配置..."

    if [ -f "$GITIGNORE_FILE" ]; then
        if grep -q "DEVELOPMENT" "$GITIGNORE_FILE"; then
            log_info "DEVELOPMENT 已在 .gitignore 中"
        else
            log_warning "DEVELOPMENT 未在 .gitignore 中"

            if [ "$AUTO_YES" = true ]; then
                log_info "非交互模式：自动添加到 .gitignore"
                echo "" >> "$GITIGNORE_FILE"
                echo "# 智慧编码配置和需求文件（可能包含敏感信息）" >> "$GITIGNORE_FILE"
                echo "DEVELOPMENT/" >> "$GITIGNORE_FILE"
                log_success "✅ 已添加 DEVELOPMENT 到 .gitignore"
            else
                echo -n "是否添加到 .gitignore？ (yes/no): "
                read -r response

                if [ "$response" = "yes" ]; then
                    echo "" >> "$GITIGNORE_FILE"
                    echo "# 智慧编码配置和需求文件（可能包含敏感信息）" >> "$GITIGNORE_FILE"
                    echo "DEVELOPMENT/" >> "$GITIGNORE_FILE"
                    log_success "✅ 已添加 DEVELOPMENT 到 .gitignore"
                fi
            fi
        fi
    else
        log_warning "未找到 .gitignore 文件"

        if [ "$AUTO_YES" = true ]; then
            log_info "非交互模式：自动创建 .gitignore"
            echo "# 智慧编码配置和需求文件（可能包含敏感信息）" > "$GITIGNORE_FILE"
            echo "DEVELOPMENT/" >> "$GITIGNORE_FILE"
            log_success "✅ 已创建 .gitignore"
        else
            echo -n "是否创建 .gitignore？ (yes/no): "
            read -r response

            if [ "$response" = "yes" ]; then
                echo "# 智慧编码配置和需求文件（可能包含敏感信息）" > "$GITIGNORE_FILE"
                echo "DEVELOPMENT/" >> "$GITIGNORE_FILE"
                log_success "✅ 已创建 .gitignore"
            fi
        fi
    fi

    # 7. 显示下一步操作
    echo ""
    log_info "========================================="
    log_success "🎉 项目初始化完成！"
    log_info "========================================="
    echo ""
    log_info "📝 下一步："
    echo ""
    echo "  1. 编辑配置文件："
    echo "     vim $DEVELOPMENT_DIR/config.json"
    echo ""
    echo "     主要配置："
    echo "     - git.main_branch: 设置主分支名称（master 或 main）"
    echo "     - ci.check_interval: CI 检查间隔（默认 30 秒）"
    echo "     - pr.monitor_interval: PR 评论监控间隔（默认 60 秒）"
    echo ""
    echo "  2. 编辑需求文件："
    echo "     vim $DEVELOPMENT_DIR/requirements.md"
    echo ""
    echo "     在 '功能需求' 部分填写："
    echo "     - 功能目标"
    echo "     - 用户故事"
    echo "     - 验收标准"
    echo ""
    echo "  3. 使用智慧编码："
    echo "     cd $PROJECT_ROOT"
    echo "     claude \"开始智慧编码\""
    echo ""
    log_info "========================================="
    echo ""
    log_info "💡 提示："
    echo "  - 配置文件位置: $DEVELOPMENT_DIR/config.json"
    echo "  - 需求文件位置: $DEVELOPMENT_DIR/requirements.md"
    echo "  - DEVELOPMENT 目录建议加入 .gitignore"
    echo ""
    log_info "📚 更多信息请查看："
    echo "  $SKILL_DIR/README.md"
    echo ""
}

# 执行主流程
main "$@"

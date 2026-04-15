#!/bin/zsh

###############################################
# 智慧编码 Skill 安装脚本
# 将 Skill 链接到本地 Claude 配置目录
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
SKILL_NAME="智慧编码"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
TARGET_DIR="$CLAUDE_SKILLS_DIR/$SKILL_NAME"

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
    log_info "开始安装智慧编码 Skill"
    log_info "========================================="

    # 1. 检查 Claude 配置目录
    if [ ! -d "$HOME/.claude" ]; then
        log_error "未找到 Claude 配置目录: $HOME/.claude"
        log_info "请确保已安装 Claude Code"
        exit 1
    fi

    # 2. 创建 skills 目录（如果不存在）
    if [ ! -d "$CLAUDE_SKILLS_DIR" ]; then
        log_info "创建 skills 目录: $CLAUDE_SKILLS_DIR"
        mkdir -p "$CLAUDE_SKILLS_DIR"
    fi

    # 3. 检查是否已安装
    if [ -L "$TARGET_DIR" ]; then
        log_warning "Skill 已安装，正在更新..."
        rm "$TARGET_DIR"
    elif [ -d "$TARGET_DIR" ]; then
        log_warning "发现同名目录（非链接），正在备份..."
        mv "$TARGET_DIR" "${TARGET_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # 4. 创建符号链接
    log_info "创建符号链接..."
    log_info "  源目录: $SCRIPT_DIR"
    log_info "  目标位置: $TARGET_DIR"

    ln -s "$SCRIPT_DIR" "$TARGET_DIR"

    if [ $? -eq 0 ]; then
        log_success "✅ Skill 安装成功！"
    else
        log_error "❌ Skill 安装失败"
        exit 1
    fi

    # 5. 验证安装
    log_info "验证安装..."
    if [ -f "$TARGET_DIR/SKILL.md" ]; then
        log_success "✅ SKILL.md 文件存在"
    else
        log_error "❌ SKILL.md 文件不存在"
        exit 1
    fi

    # 6. 验证模板文件
    log_info "验证模板文件..."

    if [ -f "$SCRIPT_DIR/config.example.json" ]; then
        log_success "✅ config.example.json 模板存在"
    else
        log_error "❌ config.example.json 模板不存在"
        exit 1
    fi

    if [ -f "$SCRIPT_DIR/requirements.example.md" ]; then
        log_success "✅ requirements.example.md 模板存在"
    else
        log_error "❌ requirements.example.md 模板不存在"
        exit 1
    fi

    if [ -f "$SCRIPT_DIR/init-project.sh" ]; then
        log_success "✅ init-project.sh 脚本存在"
    else
        log_error "❌ init-project.sh 脚本不存在"
        exit 1
    fi

    # 7. 显示安装信息
    echo ""
    log_info "========================================="
    log_success "🎉 智慧编码 Skill 安装完成！"
    log_info "========================================="
    echo ""
    log_info "📝 下一步："
    echo ""
    echo "  1. 初始化项目（在你的项目根目录运行）："
    echo "     cd /path/to/your/project"
    echo "     $TARGET_DIR/init-project.sh"
    echo "     # 这会在项目根目录创建 DEVELOPMENT 文件夹和配置文件"
    echo ""
    echo "  2. 编辑需求文件："
    echo "     cd /path/to/your/project"
    echo "     vim DEVELOPMENT/requirements.md"
    echo "     # 在\"功能需求\"部分填写你要开发的功能"
    echo ""
    echo "  3. 使用 Skill（在项目根目录运行）："
    echo "     cd /path/to/your/project"
    echo "     claude \"开始智慧编码\""
    echo ""
    log_info "========================================="
    echo ""
    log_info "💡 提示："
    echo "  - Skill 名称: $SKILL_NAME"
    echo "  - 安装位置: $TARGET_DIR"
    echo "  - 源代码位置: $SCRIPT_DIR"
    echo "  - 使用符号链接，修改源代码会立即生效"
    echo ""
    log_info "📂 工作目录结构："
    echo "  - Skill 目录: ~/.claude/skills/智慧编码/ (符号链接)"
    echo "  - 项目配置: /your-project/DEVELOPMENT/config.json"
    echo "  - 项目需求: /your-project/DEVELOPMENT/requirements.md"
    echo ""
    log_info "📚 更多信息请查看 README.md"
    echo ""
}

# 执行主流程
main "$@"

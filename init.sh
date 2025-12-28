#!/usr/bin/env bash
# 一键安装和配置 Zim + Starship + Atuin（仅配置 zsh，不修改 bashrc）
set -euo pipefail
trap 'echo "❌ 安装过程中发生错误，请查看上方输出并重试。"' ERR

HOME_BIN="$HOME/.local/bin"
ZIM_HOME="${ZIM_HOME:-${ZDOTDIR:-$HOME}/.zim}"

log() {
    local message="$1"
    printf "\n[%s] ==> %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$message"
}

add_to_path() {
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) ;; # 已存在
        *) PATH="$dir:$PATH" ;;
    esac
}

ensure_command() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ 未找到命令：$cmd"
        echo "   提示：$hint"
        exit 1
    fi
}

prepare_path() {
    add_to_path "$HOME_BIN"
    add_to_path "$HOME/.atuin/bin"
    add_to_path "$HOME/.local/share/atuin/bin"
    add_to_path "/usr/local/go/bin"
    add_to_path "$HOME/bin"
    export PATH
}

backup_bashrc() {
    if [ -f "$HOME/.bashrc" ]; then
        local backup="$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.bashrc" "$backup"
        log "🛡️ 预防性备份 .bashrc 到 $backup"
    fi
}

restore_bashrc_if_modified() {
    local backup_pattern="$HOME/.bashrc.backup.*"
    local latest_backup=$(ls -t $backup_pattern 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        return
    fi
    
    if [ -f "$HOME/.bashrc" ] && ! diff -q "$HOME/.bashrc" "$latest_backup" >/dev/null 2>&1; then
        log "⚠️ 检测到 .bashrc 被修改，正在恢复..."
        cp "$latest_backup" "$HOME/.bashrc"
        log "✓ .bashrc 已恢复"
    fi
}

install_zim() {
    if [ -d "$ZIM_HOME" ]; then
        log "Zim 已存在，跳过安装"
        return
    fi
    
    log "安装 Zim 框架"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    ensure_command zsh "请先安装 zsh（例如：sudo apt-get install zsh）"
    
    # 下载 Zim 安装脚本
    curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh -o /tmp/zim_install.zsh
    
    # 使用 zsh 执行安装脚本（非交互模式）
    zsh /tmp/zim_install.zsh -q
    rm -f /tmp/zim_install.zsh
    
    if [ -d "$ZIM_HOME" ]; then
        log "✓ Zim 安装成功：$ZIM_HOME"
    else
        echo "⚠️ Zim 安装未成功，请检查"
    fi
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        log "Starship 已存在，跳过安装"
        return
    fi
    
    log "安装 Starship 提示符"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    
    mkdir -p "$HOME_BIN"
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir="$HOME_BIN"
    
    prepare_path
    if command -v starship >/dev/null 2>&1; then
        log "✓ Starship 安装成功：$(command -v starship)"
    else
        echo "⚠️ Starship 安装后未能在 PATH 中找到"
    fi
}

install_atuin() {
    if command -v atuin >/dev/null 2>&1; then
        log "Atuin 已存在，跳过安装"
        return
    fi
    
    log "安装 Atuin 历史记录增强"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    
    export ATUIN_NOBANNER=true
    
    local install_script="/tmp/atuin_install_$$.sh"
    curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh -o "$install_script"
    bash "$install_script" --yes || true
    rm -f "$install_script"
    
    add_to_path "$HOME/.atuin/bin"
    add_to_path "$HOME/.local/share/atuin/bin"
    add_to_path "$HOME/.cargo/bin"
    export PATH
    
    sleep 1
    if command -v atuin >/dev/null 2>&1; then
        log "✓ Atuin 安装成功：$(command -v atuin)"
        atuin --version
    else
        echo "⚠️ Atuin 安装后未能在 PATH 中找到"
    fi
    
    restore_bashrc_if_modified
}

configure_zimrc() {
    log "配置 Zim 模块（.zimrc）"
    
    cat > "$HOME/.zimrc" <<'CONF'
# Zim 最小化配置

# 补全系统（必需）
zmodule completion

# 语法高亮
zmodule zdharma-continuum/fast-syntax-highlighting

# 自动建议
zmodule zsh-users/zsh-autosuggestions
CONF

    log "✓ .zimrc 配置完成（最小化）"
}

backup_zshrc() {
    if [ -f "$HOME/.zshrc" ]; then
        local backup="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.zshrc" "$backup"
        log "已备份当前 .zshrc 到 $backup"
    fi
}

write_zshrc() {
    log "生成新的 .zshrc 配置"
    
    cat > "$HOME/.zshrc" <<'CONF'
# Zsh 配置文件

# 统一 PATH 并去重
typeset -U path
path=(
    $HOME/.local/bin
    $HOME/.atuin/bin
    $HOME/.local/share/atuin/bin
    $HOME/.cargo/bin
    /usr/local/go/bin
    $HOME/go/bin
    $HOME/bin
    $path
)

# Zim 框架初始化
ZIM_HOME=${ZDOTDIR:-$HOME}/.zim

# 下载 zimfw 插件管理器（如果不存在）
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
fi

# 安装缺失的模块并更新 ${ZIM_HOME}/init.zsh（如果缺失或过时）
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-$HOME}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi

# 初始化 Zim 模块
source ${ZIM_HOME}/init.zsh

# Zsh 历史配置
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY          # 记录时间戳
setopt HIST_EXPIRE_DUPS_FIRST    # 首先删除重复条目
setopt HIST_IGNORE_DUPS          # 不记录重复的命令
setopt HIST_IGNORE_SPACE         # 忽略以空格开头的命令
setopt SHARE_HISTORY             # 多个会话共享历史

# Zsh 自动建议配置
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Python 虚拟环境自动激活
# 当进入包含虚拟环境的目录时自动激活，离开时自动停用
autoload -U add-zsh-hook

_auto_activate_venv() {
    # 如果已在虚拟环境中，检查是否需要切换或停用
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # 获取当前虚拟环境的父目录
        local parent_dir="$(dirname "$VIRTUAL_ENV")"
        
        # 如果不在虚拟环境的父目录下，停用
        if [[ "$PWD"/ != "$parent_dir"/* ]] && [[ "$PWD" != "$parent_dir" ]]; then
            deactivate 2>/dev/null
        fi
    fi
    
    # 检查常见的虚拟环境目录
    local venv_names=("venv" ".venv" "env" ".env" "virtualenv")
    local current_dir="$PWD"
    
    # 向上搜索虚拟环境（最多3层）
    local search_depth=0
    while [[ "$current_dir" != "/" ]] && [[ $search_depth -lt 3 ]]; do
        for venv_name in "${venv_names[@]}"; do
            local venv_path="$current_dir/$venv_name"
            
            # 检查虚拟环境是否存在且有效
            if [[ -f "$venv_path/bin/activate" ]]; then
                # 如果不在该虚拟环境中，则激活
                if [[ "$VIRTUAL_ENV" != "$venv_path" ]]; then
                    source "$venv_path/bin/activate"
                    echo "🐍 已激活虚拟环境: $venv_path"
                fi
                return
            fi
        done
        current_dir="$(dirname "$current_dir")"
        ((search_depth++))
    done
}

add-zsh-hook chpwd _auto_activate_venv

# 启动时检查当前目录
_auto_activate_venv

# Starship 提示符
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Atuin 历史增强（仅保留 Ctrl+R 搜索，不绑定方向键）
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi

# 自定义别名
alias ll='ls -lah'
alias la='ls -A'

# 快速目录跳转
setopt AUTO_CD              # 输入目录名自动 cd
setopt AUTO_PUSHD           # cd 时自动 pushd
setopt PUSHD_IGNORE_DUPS    # 忽略重复的目录
CONF

    log "✓ .zshrc 配置完成"
}

install_zim_modules() {
    log "安装 Zim 模块"
    
    if [ -f "$ZIM_HOME/zimfw.zsh" ]; then
        # 在 zsh 子进程中设置 ZIM_HOME 环境变量
        ZIM_HOME="$ZIM_HOME" zsh -c "source \$ZIM_HOME/zimfw.zsh && zimfw install" 2>&1 | grep -v "ZIM_HOME not defined" || true
        log "✓ Zim 模块安装完成"
    else
        echo "⚠️ zimfw.zsh 不存在，模块将在首次启动 zsh 时自动安装"
    fi
}

import_atuin_history() {
    if command -v atuin >/dev/null 2>&1; then
        log "导入历史记录（自动模式）"
        atuin import auto || echo "⚠️ Atuin 导入未成功，这可能是正常的（如果没有历史记录）"
    else
        echo "⚠️ 未检测到 Atuin，跳过历史导入"
    fi
}

set_default_shell_to_zsh() {
    if [ "${SHELL##*/}" = "zsh" ]; then
        log "当前默认 shell 已是 zsh，跳过切换"
        return
    fi
    
    if ! command -v zsh >/dev/null 2>&1; then
        echo "⚠️ 未找到 zsh，无法切换默认 shell"
        return
    fi
    
    if command -v chsh >/dev/null 2>&1; then
        log "将默认 shell 切换为 zsh（可能需要输入密码）"
        if chsh -s "$(command -v zsh)"; then
            log "✓ 默认 shell 已切换为 zsh"
        else
            echo "⚠️ 默认 shell 切换未成功，请手动执行：chsh -s $(command -v zsh)"
        fi
    else
        echo "⚠️ 未找到 chsh，请手动执行：chsh -s $(command -v zsh)"
    fi
}

print_verification() {
    log "验证安装结果"
    echo ""
    echo "安装位置检查："
    
    if [ -d "$ZIM_HOME" ]; then
        printf " ✓ %-10s -> %s\n" "Zim" "$ZIM_HOME"
    else
        printf " ✗ %-10s -> 未找到\n" "Zim"
    fi
    
    for cmd in starship atuin; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf " ✓ %-10s -> %s\n" "$cmd" "$(command -v $cmd)"
        else
            printf " ✗ %-10s -> 未找到\n" "$cmd"
        fi
    done
    
    echo ""
    echo "配置文件状态："
    printf " ✓ .zshrc  -> 已配置\n"
    printf " ✓ .zimrc  -> 已配置\n"
    printf " ✓ .bashrc -> 未修改（已保护）\n"
    echo ""
}

main() {
    log "开始设置开发终端环境（使用 Zim 框架）"
    
    prepare_path
    ensure_command zsh "请先安装 zsh（例如：sudo apt-get install zsh）"
    
    # 预防性备份 bashrc
    backup_bashrc
    
    # 安装各个组件
    install_zim
    install_starship
    install_atuin
    
    # 配置文件
    configure_zimrc
    backup_zshrc
    write_zshrc
    
    # 安装 Zim 模块
    install_zim_modules
    
    # 导入历史并切换 shell
    import_atuin_history
    set_default_shell_to_zsh
    
    # 最后检查 bashrc
    restore_bashrc_if_modified
    
    print_verification
    
    echo "✅ 配置完成！"
    echo ""
    echo "下一步："
    echo " 1. 执行 'zsh' 切换到 zsh shell"
    echo " 2. 或者重新登录以使默认 shell 生效"
    echo " 3. 使用 'zimfw update' 更新模块"
    echo " 4. 使用 'zimfw info' 查看已安装模块"
    echo ""
    echo "注意："
    echo " • 本脚本使用 Zim 框架管理 Zsh 插件"
    echo " • 不会修改 .bashrc 文件"
    echo " • 配置文件位置：~/.zshrc 和 ~/.zimrc"
}

main "$@"

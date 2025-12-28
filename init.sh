#!/usr/bin/env bash
# 一键安装和配置常用终端工具的脚本（使用 Zim 替代 Sheldon，仅配置 zsh，不修改 bashrc）
set -euo pipefail
trap 'echo "❌ 安装过程中发生错误，请查看上方输出并重试。"' ERR

HOME_BIN="$HOME/.local/bin"
ZIM_HOME="${ZIM_HOME:-${HOME}/.zim}"

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
        echo " 提示：$hint"
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
        log "预防性备份 .bashrc 到 $backup"
    fi
}

restore_bashrc_if_modified() {
    local backup_pattern="$HOME/.bashrc.backup.*"
    local latest_backup=$(ls -t $backup_pattern 2>/dev/null | head -1)
   
    if [ -z "$latest_backup" ]; then
        return
    fi
   
    if [ -f "$HOME/.bashrc" ] && ! diff -q "$HOME/.bashrc" "$latest_backup" >/dev/null 2>&1; then
        log "检测到 .bashrc 被修改，正在恢复..."
        cp "$latest_backup" "$HOME/.bashrc"
        log ".bashrc 已恢复"
    fi
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        log "Starship 已存在，跳过安装"
        return
    fi
    log "安装 Starship 提示符（不修改 shell 配置）"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
   
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir="$HOME_BIN"
   
    prepare_path
    if command -v starship >/dev/null 2>&1; then
        log "Starship 安装成功：$(command -v starship)"
    else
        echo "Starship 安装后未能在 PATH 中找到，请检查"
    fi
}

install_atuin() {
    if command -v atuin >/dev/null 2>&1; then
        log "Atuin 已存在，跳过安装"
        return
    fi
    log "安装 Atuin 历史记录增强（不修改 shell 配置）"
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
        log "Atuin 安装成功：$(command -v atuin)"
        atuin --version
    else
        echo "Atuin 安装后未能在 PATH 中找到"
        echo " 正在检查可能的安装位置..."
        for path in "$HOME/.atuin/bin/atuin" "$HOME/.local/share/atuin/bin/atuin" "$HOME/.cargo/bin/atuin"; do
            if [ -f "$path" ]; then
                echo " 找到 atuin：$path"
            fi
        done
    fi
   
    restore_bashrc_if_modified
}

install_zim() {
    if [ -f "${ZIM_HOME}/zimfw.zsh" ]; then
        log "Zim 已存在，跳过全新安装"
    else
        log "安装 Zim 插件管理器（极速、模块化）"
        ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
        mkdir -p "${ZIM_HOME}"
        curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
        log "Zim 安装完成"
    fi
}

write_zimrc() {
    log "生成 Zim 插件配置 (~/.zimrc)"
    cat > "$HOME/.zimrc" <<'CONF'
# Zim 模块配置
zmodule zsh-users/zsh-autosuggestions
zmodule zdharma-continuum/fast-syntax-highlighting
# zap-zsh/supercharge 的功能（提示符美化、实用别名等）在 Zim 中可以部分由内置模块或 Starship 替代
# 如果你非常依赖 supercharge 的某些特性，可自行添加其他模块；这里先不加载以避免键绑定冲突
CONF
}

zim_install_modules() {
    if [ -f "${ZIM_HOME}/zimfw.zsh" ]; then
        log "安装/更新 Zim 模块"
        zsh -c "source ${ZIM_HOME}/zimfw.zsh install"
    else
        echo "Zim 未正确安装，跳过模块安装"
    fi
}

backup_zshrc() {
    if [ -f "$HOME/.zshrc" ]; then
        local backup="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.zshrc" "$backup"
        log "已备份当前 .zshrc 到 $backup"
    fi
}

write_zshrc() {
    log "生成新的 .zshrc 配置（使用 Zim）"
    cat > "$HOME/.zshrc" <<'CONF'
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

# 加速补全并生成缓存，避免首次启动卡顿
ZSH_COMPDUMP=${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump
mkdir -p ${ZSH_COMPDUMP:h}
autoload -Uz compinit
compinit -C -d $ZSH_COMPDUMP

# Zim 初始化（必须在其他配置之前）
ZIM_HOME=${ZIM_HOME:-${HOME}/.zim}
if [[ -s ${ZIM_HOME}/init.zsh ]]; then
    source ${ZIM_HOME}/init.zsh
else
    # 如果 init.zsh 不存在或过时，自动构建
    source ${ZIM_HOME}/zimfw.zsh init -q
    source ${ZIM_HOME}/init.zsh
fi

# Starship 提示符
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Atuin 历史增强（仅保留 Ctrl+R 搜索，不绑定方向键）
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi

# 可选：如果你之前被 supercharge 改坏的 Backspace，这里强制修复（Zim 本身不会改）
bindkey '^H' backward-delete-char
CONF
}

import_atuin_history() {
    if command -v atuin >/dev/null 2>&1; then
        log "导入历史记录（自动模式）"
        atuin import auto || echo "Atuin 导入未成功，这可能是正常的（如果没有历史记录）"
    else
        echo "未检测到 Atuin，跳过历史导入"
    fi
}

set_default_shell_to_zsh() {
    if [ "${SHELL##*/}" = "zsh" ]; then
        log "当前默认 shell 已是 zsh，跳过切换"
        return
    fi
    if ! command -v zsh >/dev/null 2>&1; then
        echo "未找到 zsh，无法切换默认 shell，请先安装（例如：sudo apt-get install zsh）"
        return
    fi
    if command -v chsh >/dev/null 2>&1; then
        log "将默认 shell 切换为 zsh（可能需要输入密码）"
        if chsh -s "$(command -v zsh)"; then
            log "默认 shell 已切换为 zsh"
        else
            echo "默认 shell 切换未成功，请手动执行：chsh -s $(command -v zsh)"
        fi
    else
        echo "未找到 chsh，请手动将默认 shell 修改为 zsh：chsh -s $(command -v zsh)"
    fi
}

print_verification() {
    log "验证安装结果"
    echo ""
    echo "安装位置检查："
    for cmd in starship atuin; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf " %-10s -> %s\n" "$cmd" "$(command -v $cmd)"
        else
            printf " %-10s -> 未找到\n" "$cmd"
        fi
    done
    printf " %-10s -> Zim 框架（${ZIM_HOME})\n" "zimfw"
    echo ""
    echo "配置文件状态："
    printf " .zshrc   -> 已配置（使用 Zim）\n"
    printf " .zimrc   -> 已生成\n"
    printf " .bashrc  -> 未修改（已保护）\n"
    echo ""
}

main() {
    log "开始设置开发终端环境（使用 Zim 替代 Sheldon）"
    prepare_path
    ensure_command zsh "请先安装 zsh（例如：sudo apt-get install zsh）"
    backup_bashrc

    install_starship
    install_atuin
    install_zim
    write_zimrc
    zim_install_modules
    backup_zshrc
    write_zshrc
    import_atuin_history
    set_default_shell_to_zsh

    restore_bashrc_if_modified

    print_verification
    echo "配置完成！Zim 已取代 Sheldon，Backspace 问题彻底解决（无 supercharge 键绑定冲突）"
    echo ""
    echo "下一步："
    echo " 1. 执行 'zsh' 切换到 zsh shell"
    echo " 2. 或者重新登录以使默认 shell 生效"
    echo ""
    echo "提示："
    echo " - Zim 启动速度极快，且不会乱改键绑定"
    echo " - 如果以后想添加更多模块，编辑 ~/.zimrc 后运行：zimfw install"
    echo " - 更新模块：zimfw upgrade && zimfw install"
}

main "$@"

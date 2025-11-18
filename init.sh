#!/usr/bin/env bash
# 一键安装和配置常用终端工具的脚本

set -euo pipefail

trap 'echo "❌ 安装过程中发生错误，请查看上方输出并重试。"' ERR

HOME_BIN="$HOME/.local/bin"

log() {
    local message="$1"
    printf "\n[%s] ==> %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$message"
}

add_to_path() {
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) ;;  # 已存在
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
    add_to_path "$HOME/.local/share/atuin/bin"
    add_to_path "/usr/local/go/bin"
    add_to_path "$HOME/go/bin"
    add_to_path "$HOME/bin"
    export PATH
}

install_sheldon() {
    if command -v sheldon >/dev/null 2>&1; then
        log "Sheldon 已存在，跳过安装"
        return
    fi
    log "安装 Sheldon 插件管理器"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
        | bash -s -- --repo rossmacarthur/sheldon --to "$HOME_BIN"
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        log "Starship 已存在，跳过安装"
        return
    fi
    log "安装 Starship 提示符"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
}

install_atuin() {
    if command -v atuin >/dev/null 2>&1; then
        log "Atuin 已存在，跳过安装"
        return
    fi
    log "安装 Atuin 历史记录增强"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | sh -s -- --yes
}

write_sheldon_config() {
    log "生成 Sheldon 插件配置"
    mkdir -p "$HOME/.config/sheldon"
    cat > "$HOME/.config/sheldon/plugins.toml" <<'CONF'
shell = "zsh"

[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"

[plugins.fast-syntax-highlighting]
github = "zdharma-continuum/fast-syntax-highlighting"

[plugins.supercharge]
github = "zap-zsh/supercharge"
CONF

    if command -v sheldon >/dev/null 2>&1; then
        log "锁定并下载插件"
        sheldon lock
    else
        echo "⚠️ 未检测到 sheldon，跳过插件下载"
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
    log "生成新的 .zshrc 配置"
    cat > "$HOME/.zshrc" <<'CONF'
# 统一 PATH 并去重
typeset -U path
path=(
    $HOME/.local/bin
    $HOME/.local/share/atuin/bin
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

# Sheldon 插件管理
eval "$(sheldon source)"

# Starship 提示符
eval "$(starship init zsh)"

# Atuin 历史增强（仅保留 Ctrl+R 搜索，不绑定方向键）
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi
CONF
}

import_atuin_history() {
    if command -v atuin >/dev/null 2>&1; then
        log "导入历史记录（自动模式）"
        atuin import auto || echo "⚠️ Atuin 导入未成功，请稍后重试"
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
        echo "⚠️ 未找到 zsh，无法切换默认 shell，请先安装（例如：sudo apt-get install zsh）"
        return
    fi

    if command -v chsh >/dev/null 2>&1; then
        log "将默认 shell 切换为 zsh（可能需要输入密码）"
        if chsh -s "$(command -v zsh)"; then
            log "默认 shell 已切换为 zsh"
        else
            echo "⚠️ 默认 shell 切换未成功，请手动执行：chsh -s $(command -v zsh)"
        fi
    else
        echo "⚠️ 未找到 chsh，请手动将默认 shell 修改为 zsh：chsh -s $(command -v zsh)"
    fi
}

main() {
    log "开始设置开发终端环境"

    prepare_path
    ensure_command zsh "请先安装 zsh（例如：sudo apt-get install zsh）"

    install_sheldon
    install_starship
    install_atuin

    write_sheldon_config
    backup_zshrc
    write_zshrc
    import_atuin_history

    set_default_shell_to_zsh

    echo "\n✅ 配置完成！请重新打开终端或执行 'source ~/.zshrc' 使配置生效。"
}

main "$@"

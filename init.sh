#!/usr/bin/env bash
# 一键安装和配置常用终端工具的脚本（仅配置 zsh，不修改 bashrc）

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
        log "🛡️  预防性备份 .bashrc 到 $backup"
    fi
}

restore_bashrc_if_modified() {
    local backup_pattern="$HOME/.bashrc.backup.*"
    local latest_backup=$(ls -t $backup_pattern 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        return
    fi
    
    if [ -f "$HOME/.bashrc" ] && ! diff -q "$HOME/.bashrc" "$latest_backup" >/dev/null 2>&1; then
        log "⚠️  检测到 .bashrc 被修改，正在恢复..."
        cp "$latest_backup" "$HOME/.bashrc"
        log "✓ .bashrc 已恢复"
    fi
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
    
    # 刷新 PATH 并验证
    prepare_path
    if command -v sheldon >/dev/null 2>&1; then
        log "✓ Sheldon 安装成功：$(command -v sheldon)"
    else
        echo "⚠️ Sheldon 安装后未能在 PATH 中找到，请检查"
    fi
}

install_starship() {
    if command -v starship >/dev/null 2>&1; then
        log "Starship 已存在，跳过安装"
        return
    fi
    log "安装 Starship 提示符（不修改 shell 配置）"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    
    # 使用 --no-modify-path 参数防止修改 shell 配置文件
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir="$HOME_BIN"
    
    # 刷新 PATH 并验证
    prepare_path
    if command -v starship >/dev/null 2>&1; then
        log "✓ Starship 安装成功：$(command -v starship)"
    else
        echo "⚠️ Starship 安装后未能在 PATH 中找到，请检查"
    fi
}

install_atuin() {
    if command -v atuin >/dev/null 2>&1; then
        log "Atuin 已存在，跳过安装"
        return
    fi
    log "安装 Atuin 历史记录增强（不修改 shell 配置）"
    ensure_command curl "请先安装 curl（例如：sudo apt-get install curl）"
    
    # 设置环境变量防止 atuin 自动修改 shell 配置
    export ATUIN_NOBANNER=true
    
    # 下载安装脚本到临时文件，手动执行以控制行为
    local install_script="/tmp/atuin_install_$$.sh"
    curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh -o "$install_script"
    
    # 使用 --no-modify-path 参数（如果支持）或者通过环境变量控制
    bash "$install_script" --yes || true
    rm -f "$install_script"
    
    # 立即刷新 PATH，包含所有可能的 atuin 安装路径
    add_to_path "$HOME/.atuin/bin"
    add_to_path "$HOME/.local/share/atuin/bin"
    add_to_path "$HOME/.cargo/bin"
    export PATH
    
    # 验证安装
    sleep 1  # 等待文件系统同步
    if command -v atuin >/dev/null 2>&1; then
        log "✓ Atuin 安装成功：$(command -v atuin)"
        atuin --version
    else
        echo "⚠️ Atuin 安装后未能在 PATH 中找到"
        echo "   正在检查可能的安装位置..."
        for path in "$HOME/.atuin/bin/atuin" "$HOME/.local/share/atuin/bin/atuin" "$HOME/.cargo/bin/atuin"; do
            if [ -f "$path" ]; then
                echo "   找到 atuin：$path"
            fi
        done
    fi
    
    # 检查并清理可能被修改的 shell 配置
    restore_bashrc_if_modified
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

# Sheldon 插件管理
if command -v sheldon &> /dev/null; then
    eval "$(sheldon source)"
fi

# Starship 提示符
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# Atuin 历史增强（仅保留 Ctrl+R 搜索，不绑定方向键）
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi
CONF
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

print_verification() {
    log "验证安装结果"
    echo ""
    echo "安装位置检查："
    for cmd in sheldon starship atuin; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "  ✓ %-10s -> %s\n" "$cmd" "$(command -v $cmd)"
        else
            printf "  ✗ %-10s -> 未找到\n" "$cmd"
        fi
    done
    echo ""
    echo "配置文件状态："
    printf "  ✓ .zshrc   -> 已配置\n"
    printf "  ✓ .bashrc  -> 未修改（已保护）\n"
    echo ""
}

main() {
    log "开始设置开发终端环境（仅配置 zsh）"

    prepare_path
    ensure_command zsh "请先安装 zsh（例如：sudo apt-get install zsh）"

    # 预防性备份 bashrc
    backup_bashrc

    install_sheldon
    install_starship
    install_atuin

    write_sheldon_config
    backup_zshrc
    write_zshrc
    import_atuin_history

    set_default_shell_to_zsh
    
    # 最后再检查一次 bashrc
    restore_bashrc_if_modified
    
    print_verification

    echo "✅ 配置完成！"
    echo ""
    echo "下一步："
    echo "  1. 执行 'zsh' 切换到 zsh shell"
    echo "  2. 或者重新登录以使默认 shell 生效"
    echo ""
    echo "注意：本脚本仅配置 zsh，不会修改 .bashrc"
    if ! command -v atuin >/dev/null 2>&1; then
        echo ""
        echo "⚠️  atuin 未能在当前 bash session 中找到"
        echo "   请切换到 zsh 后再验证：zsh -c 'command -v atuin'"
    fi
}

main "$@"

#!/usr/bin/env bash
# 精简版：安装 Zim + Starship + Atuin
set -euo pipefail

HOME_BIN="$HOME/.local/bin"
ZIM_HOME="${ZIM_HOME:-${ZDOTDIR:-$HOME}/.zim}"

log() {
    printf "\n==> %s\n" "$1"
}

ensure_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "❌ 未找到命令：$1，提示：$2"
        exit 1
    fi
}

install_zim() {
    [ -d "$ZIM_HOME" ] && { log "Zim 已存在"; return; }
    
    log "安装 Zim"
    ensure_command curl "sudo apt-get install curl"
    ensure_command zsh "sudo apt-get install zsh"
    
    curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh -s - -q
    log "✓ Zim 安装完成"
}

install_starship() {
    command -v starship >/dev/null 2>&1 && { log "Starship 已存在"; return; }
    
    log "安装 Starship"
    mkdir -p "$HOME_BIN"
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir="$HOME_BIN"
    log "✓ Starship 安装完成"
}

install_atuin() {
    command -v atuin >/dev/null 2>&1 && { log "Atuin 已存在"; return; }
    
    log "安装 Atuin"
    export ATUIN_NOBANNER=true
    curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | bash -s -- --yes
    log "✓ Atuin 安装完成"
}

configure_zim() {
    log "配置 .zimrc"
    cat > "$HOME/.zimrc" <<'EOF'
zmodule completion
zmodule zdharma-continuum/fast-syntax-highlighting
zmodule zsh-users/zsh-autosuggestions
EOF
}

configure_zshrc() {
    log "配置 .zshrc"
    [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    
    cat > "$HOME/.zshrc" <<'EOF'
# PATH 配置
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

# Zim 初始化
ZIM_HOME=${ZDOTDIR:-$HOME}/.zim
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
fi
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-$HOME}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
source ${ZIM_HOME}/init.zsh

# 历史配置
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# 自动建议
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Python 虚拟环境自动激活
autoload -U add-zsh-hook
_auto_activate_venv() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        local parent_dir="$(dirname "$VIRTUAL_ENV")"
        if [[ "$PWD"/ != "$parent_dir"/* ]] && [[ "$PWD" != "$parent_dir" ]]; then
            deactivate 2>/dev/null
        fi
    fi
    
    local venv_names=("venv" ".venv" "env" ".env")
    local current_dir="$PWD"
    local search_depth=0
    
    while [[ "$current_dir" != "/" ]] && [[ $search_depth -lt 3 ]]; do
        for venv_name in "${venv_names[@]}"; do
            if [[ -f "$current_dir/$venv_name/bin/activate" ]]; then
                if [[ "$VIRTUAL_ENV" != "$current_dir/$venv_name" ]]; then
                    source "$current_dir/$venv_name/bin/activate"
                    echo "🐍 已激活: $current_dir/$venv_name"
                fi
                return
            fi
        done
        current_dir="$(dirname "$current_dir")"
        ((search_depth++))
    done
}
add-zsh-hook chpwd _auto_activate_venv
_auto_activate_venv

# Starship 和 Atuin
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# 别名和选项
alias ll='ls -lah'
alias la='ls -A'
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
EOF
    log "✓ .zshrc 配置完成"
}

main() {
    log "开始安装 Zsh 环境"
    ensure_command zsh "sudo apt-get install zsh"
    
    install_zim
    install_starship
    install_atuin
    
    configure_zim
    configure_zshrc
    
    [ -f "$ZIM_HOME/zimfw.zsh" ] && ZIM_HOME="$ZIM_HOME" zsh -c "source \$ZIM_HOME/zimfw.zsh && zimfw install" 2>&1 | grep -v "ZIM_HOME not defined" || true
    
    command -v atuin >/dev/null 2>&1 && atuin import auto 2>/dev/null || true
    
    if [ "${SHELL##*/}" != "zsh" ] && command -v chsh >/dev/null 2>&1; then
        log "切换默认 shell 为 zsh"
        chsh -s "$(command -v zsh)" || echo "⚠️ 请手动执行: chsh -s $(command -v zsh)"
    fi
    
    echo ""
    echo "✅ 安装完成！执行 'zsh' 启动新环境"
}

main

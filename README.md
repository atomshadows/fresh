# 开发终端环境快速配置

该仓库提供一个在全新 Linux 机器上快速安装和配置常用终端工具的脚本，包含 Sheldon 插件管理器、Starship 提示符与 Atuin 历史增强。

## 使用方法

```bash
chmod +x init.sh
./init.sh
```

> 脚本会自动备份现有的 `~/.zshrc`（如存在），统一整理 PATH，开启补全缓存以避免首次启动卡顿，并将默认 shell 切换为 `zsh`。安装日志和提示均为中文，便于排查问题。Atuin 仅保留 Ctrl+R 搜索历史，不会占用方向键。

## 一键下载安装
无需提前克隆仓库，可直接使用 `curl` 或 `wget` 一行命令完成下载与执行（请将 `<你的GitHub用户名>` 替换为实际用户名）：

```bash
# 通过 curl
bash -c "$(curl -fsSL https://raw.githubusercontent.com/<你的GitHub用户名>/fresh/main/init.sh)"

# 或者通过 wget
bash -c "$(wget -qO- https://raw.githubusercontent.com/<你的GitHub用户名>/fresh/main/init.sh)"
```

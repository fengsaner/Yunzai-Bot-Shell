#!/bin/env bash
# 颜色定义
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
blue="\033[34m"
cyan="\033[36m"
reset="\033[0m"

# 检查是否已安装
if [ -x /usr/local/bin/ffmpeg ]; then
  echo -e "${blue}[*] ${green}FFmpeg已安装，无需重复操作${reset}"
  exit 0
fi

# 清理无效文件
if [ -e /usr/local/bin/ffmpeg ]; then
  echo -e "${blue}[*] ${yellow}移除无效的ffmpeg文件...${reset}"
  rm -f /usr/local/bin/ffmpeg /usr/local/bin/ffprobe
fi

# 检测架构
arch=$(uname -m)
case $arch in
  aarch64|arm64) arch="arm64" ;;
  x86_64|x64|amd64) arch="x64" ;;
  *) echo -e "${blue}[*] ${red}不支持的架构：$arch${reset}"; exit 1 ;;
esac

# 国内源地址（npm镜像，稳定可靠）
base_url="https://registry.npmmirror.com/-/binary/ffmpeg-static/b6.0"
ffmpeg_url="${base_url}/ffmpeg-linux-${arch}"
ffprobe_url="${base_url}/ffprobe-linux-${arch}"

# 下载函数（仅用curl，兼容性更好）
download() {
  local file=$1
  local url=$2
  echo -e "${blue}[*] ${cyan}正在下载 ${file}...${reset}"
  if curl -fL --progress-bar -o "$file" "$url"; then
    echo -e "${blue}[*] ${green}${file} 下载成功${reset}"
    return 0
  else
    echo -e "${blue}[*] ${red}${file} 下载失败${reset}"
    return 1
  fi
}

# 开始下载
echo -e "${blue}[*] ${cyan}开始安装FFmpeg（架构：$arch）...${reset}"
if download "ffmpeg" "$ffmpeg_url" && download "ffprobe" "$ffprobe_url"; then
  # 赋予权限并移动
  chmod +x ffmpeg ffprobe
  if mv ffmpeg /usr/local/bin/ && mv ffprobe /usr/local/bin/; then
    echo -e "${blue}[*] ${green}FFmpeg安装成功！${reset}"
    # 验证
    ffmpeg -version >/dev/null 2>&1 && echo -e "${blue}[*] ${green}验证通过，可直接使用ffmpeg命令${reset}"
  else
    echo -e "${blue}[*] ${red}移动文件失败，请检查/usr/local/bin权限${reset}"
    rm -f ffmpeg ffprobe
  fi
else
  echo -e "${blue}[*] ${red}下载失败，请检查网络或尝试手动下载：${reset}"
  echo -e "  ffmpeg: $ffmpeg_url"
  echo -e "  ffprobe: $ffprobe_url"
fi
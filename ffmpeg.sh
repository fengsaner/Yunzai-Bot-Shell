#!/bin/env bash
black="\e[30m"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
blue="\033[34m"
purple="\033[35m"
cyan="\033[36m"
white="\033[37m"
background="\033[0m"

# 计数器函数，用于控制下载重试次数
function IncrementCounter(){
  if [ -z ${count} ]
  then
    count=0
  fi
  ((count++))
  case ${count} in
    3)
      count=0
      return 1
      ;;
  esac
  return 0
}

# 下载函数，支持wget和curl
function Download(){
  local file="$1"
  local URL="$2"
  local count=0  # 局部变量，避免多次调用冲突
  
  DownloadStart(){
    echo -e ${blue}[${green}*${blue}] ${cyan}正在下载 ${yellow}${file}${cyan}${background}
    echo -e ${blue}[${green}*${blue}] ${cyan}下载地址: ${yellow}${URL}${background}
    until ${Command}
    do
      if ! IncrementCounter
      then
        echo -e ${blue}[${red}*${blue}] ${cyan}错误次数过多 ${yellow}退出${background}
        return 1
      fi
      echo -e ${blue}[${red}*${blue}] ${cyan}下载失败 ${yellow}三秒后重试${background}
      sleep 3s
    done
    echo -e ${blue}[${green}*${blue}] ${cyan}下载完成.${background}
    return 0
  }
  
  # 优先使用带进度条的wget
  if command -v wget > /dev/null 2>&1 && wget --help | grep -q show-progress
  then
    Command="wget --quiet --show-progress --output-document=\"${file}\" --continue \"${URL}\""
    DownloadStart
  # 其次使用带进度条的curl
  elif command -v curl > /dev/null 2>&1 && curl --help | grep -q progress-bar
  then
    Command="curl --output \"${file}\" --progress-bar --location --continue-at - \"${URL}\""
    DownloadStart
  # 最后使用基本的wget
  elif command -v wget > /dev/null 2>&1
  then
    Command="wget --output-document=\"${file}\" --continue \"${URL}\""
    DownloadStart
  else
    echo -e ${blue}[${red}*${blue}] ${cyan}未找到wget或curl下载工具.${background}
    return 1
  fi
}

# 检测系统架构
Arch(){
  case $(uname -m) in
    aarch64|arm64)
      echo arm64
      ;;
    x86_64|x64|amd64)
      echo x64
      ;;
    *)
      echo -e ${blue}[${red}*${blue}] ${cyan}不支持的架构: $(uname -m)${background}
      exit 1
      ;;
  esac
}

# 检查是否已安装ffmpeg
if [ -x /usr/local/bin/ffmpeg ]
then
  echo -e ${blue}[${green}*${blue}] ${cyan}FFmpeg已安装.${background}
  exit 0
elif [ -e /usr/local/bin/ffmpeg ]
then
  echo -e ${blue}[${yellow}*${blue}] ${cyan}移除无效的ffmpeg文件.${background}
  rm -f /usr/local/bin/ffmpeg
fi

echo -e ${blue}[${green}*${blue}] ${cyan}开始安装FFmpeg和FFprobe...${background}

# 获取架构信息
ARCH=$(Arch)

# 定义主要下载源和备用下载源
PRIMARY_URL="https://dir.fengsaner.xyz/https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux-${ARCH}-gpl.tar.xz"
BACKUP_URL1="https://registry.npmmirror.com/-/binary/ffmpeg-static/b6.0/ffmpeg-linux-${ARCH}"
BACKUP_URL2="https://cdn.npmmirror.com/binaries/ffmpeg-static/b6.0/ffmpeg-linux-${ARCH}"

# 尝试从主要源下载
if ! Download ffmpeg.tar.xz "${PRIMARY_URL}"; then
  echo -e ${blue}[${yellow}*${blue}] ${cyan}尝试备用下载源1...${background}
  # 尝试备用源1（单个文件版本）
  if Download ffmpeg "${BACKUP_URL1}" && Download ffprobe "${BACKUP_URL1/ffmpeg/ffprobe}"; then
    chmod +x ffmpeg ffprobe
    if mv -f ffmpeg /usr/local/bin/ffmpeg && mv -f ffprobe /usr/local/bin/ffprobe; then
      echo -e ${blue}[${green}*${blue}] ${cyan}从备用源1安装完成.${background}
      exit 0
    else
      echo -e ${blue}[${red}*${blue}] ${cyan}移动文件失败，请检查权限.${background}
      rm -f ffmpeg ffprobe
      exit 1
    fi
  else
    echo -e ${blue}[${yellow}*${blue}] ${cyan}尝试备用下载源2...${background}
    # 尝试备用源2
    if Download ffmpeg "${BACKUP_URL2}" && Download ffprobe "${BACKUP_URL2/ffmpeg/ffprobe}"; then
      chmod +x ffmpeg ffprobe
      if mv -f ffmpeg /usr/local/bin/ffmpeg && mv -f ffprobe /usr/local/bin/ffprobe; then
        echo -e ${blue}[${green}*${blue}] ${cyan}从备用源2安装完成.${background}
        exit 0
      else
        echo -e ${blue}[${red}*${blue}] ${cyan}移动文件失败，请检查权限.${background}
        rm -f ffmpeg ffprobe
        exit 1
      fi
    else
      echo -e ${blue}[${red}*${blue}] ${cyan}所有下载源均失败，无法继续安装.${background}
      exit 1
    fi
  fi
fi

# 处理从主要源下载的压缩包
mkdir -p ffmpeg
# 检查pv是否存在，不存在则直接使用tar解压
if command -v pv > /dev/null 2>&1; then
  pv ffmpeg.tar.xz | tar -Jxf - -C ffmpeg
else
  tar -Jxf ffmpeg.tar.xz -C ffmpeg
fi

# 处理解压后的文件
FFMPEG_DIR=$(find ffmpeg -maxdepth 1 -type d | tail -n 1)
if [ -n "${FFMPEG_DIR}" ] && [ -d "${FFMPEG_DIR}/bin" ]
then
  chmod +x ${FFMPEG_DIR}/bin/*
  if mv -f ${FFMPEG_DIR}/bin/ff* /usr/local/bin/
  then
    echo -e ${blue}[${green}*${blue}] ${cyan}安装完成.${background}
  else
    echo -e ${blue}[${red}*${blue}] ${cyan}移动文件失败，请检查权限.${background}
    exit 1
  fi
else
  echo -e ${blue}[${red}*${blue}] ${cyan}解压文件结构不符合预期.${background}
  exit 1
fi

# 清理临时文件
rm -rf ffmpeg*
    
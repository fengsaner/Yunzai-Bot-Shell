#!/bin/env bash
export red="\033[31m"
export green="\033[32m"
export yellow="\033[33m"
export blue="\033[34m"
export purple="\033[35m"
export cyan="\033[36m"
export white="\033[37m"
export background="\033[0m"

# 检查必要工具
ensure_deps() {
    if ! dpkg -s xz-utils wget &> /dev/null; then
        echo -e ${yellow}安装必要工具...${background}
        until apt install -y xz-utils wget
        do
            echo -e ${red}工具安装失败，3秒后重试${background}
            sleep 3s
        done
    fi
}
ensure_deps

# 架构判断（适配arm64/arch64）
check_arch() {
    if [[ $(uname -m) == "arm64" || $(uname -m) == "aarch64" ]]; then
        ARCH="linux-arm64"
        # arm64对应版本的Node.js链接（国内镜像，稳定）
        NODE_URL="https://npmmirror.com/mirrors/node/v22.18.0/node-v22.18.0-linux-arm64.tar.xz"
        NODE_FILE="node-v22.18.0-linux-arm64.tar.xz"
        echo -e ${green}检测到arm64架构，使用指定版本：v22.18.0${background}
    else
        echo ${red}当前架构$(uname -m)不匹配arm64${background}
        echo -e ${yellow}请手动下载对应架构的版本：https://npmmirror.com/mirrors/node/${background}
        exit 1
    fi
}

# 检查已安装的Node.js
check_node() {
    if [ -x "$(command -v node)" ]; then
        echo -e ${green}已安装Node.js：$(node -v)${background}
        return 0
    else
        return 1
    fi
}

# 从arm64专用链接安装
install_node() {
    echo -e ${yellow}开始下载Node.js（arm64）：${NODE_URL}${background}
    i=1
    until wget -O ${NODE_FILE} -c ${NODE_URL}
    do
        if [ $i -ge 3 ]; then
            echo -e ${red}下载失败，尝试手动安装${background}
            manual_install
            return
        fi
        i=$((i+1))
        echo -e ${red}下载失败，3秒后重试（第$i次）${background}
        sleep 3s
    done

    # 安装（适配arm64的解压路径）
    echo -e ${yellow}解压安装...${background}
    sudo tar -xJf ${NODE_FILE} -C /usr/local --strip-components=1
    rm -f ${NODE_FILE}

    # 验证安装
    if [ -x "$(command -v node)" ]; then
        echo -e ${green}Node.js（arm64）安装成功：$(node -v)${background}
    else
        echo -e ${red}安装失败，尝试手动安装${background}
        manual_install
    fi
}

# 手动安装指引（arm64专用）
manual_install() {
    echo -e ${white}=========================${background}
    echo -e ${yellow}请执行以下步骤手动安装（arm64）：${background}
    echo -e 1. 下载文件：${NODE_URL}
    echo -e 2. 上传到当前目录
    echo -e 3. 运行命令：sudo tar -xJf ${NODE_FILE} -C /usr/local --strip-components=1
    echo -e ${white}=========================${background}
    exit 1
}

# 主逻辑
if ! check_node; then
    check_arch
    install_node
fi

# 其他工具安装（适配arm64）
if ! dpkg -s chromium-browser >/dev/null 2>&1
then
    echo -e ${yellow}安装chromium浏览器（arm64）${background}
    until bash <(curl -sL https://gitee.com/baihu433/chromium/raw/master/chromium.sh)
    do
        echo -e ${red}安装失败 3秒后重试${background}
        sleep 3s
    done
fi

if ! dpkg -s fonts-wqy-zenhei fonts-wqy-microhei >/dev/null 2>&1
then
    echo -e ${yellow}安装中文字体包${background}
    until apt install -y fonts-wqy*
    do
        echo -e ${red}安装失败 3秒后重试${background}
        sleep 3s
    done
fi

if [ ! -x "/usr/local/bin/ffmpeg" ];then
  if ping -c 1 gitee.com > /dev/null 2>&1
  then
    echo -e ${yellow}安装ffmpeg（arm64）${background}
    ffmpeg_URL=https://registry.npmmirror.com/-/binary/ffmpeg-static/b6.0/
    wget -O ffmpeg -c ${ffmpeg_URL}/ffmpeg-linux-arm64
    wget -O ffprobe -c ${ffmpeg_URL}/ffprobe-linux-arm64
    chmod +x ffmpeg ffprobe
    mv -f ffmpeg /usr/local/bin/ffmpeg
    mv -f ffprobe /usr/local/bin/ffprobe
  else
    if [ ! -d ffmpeg ];then
      mkdir ffmpeg
    fi
    ffmpegURL=https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz
    wget -O ffmpeg.tar.xz -c ${ffmpegURL}
    pv ffmpeg.tar.xz | tar -Jxf - -C ffmpeg
    chmod +x ffmpeg/$(ls ffmpeg)/*
    mv -f ffmpeg/$(ls ffmpeg)/ffmpeg /usr/local/bin/ffmpeg
    mv -f ffmpeg/$(ls ffmpeg)/ffprobe /usr/local/bin/ffprobe
    rm -rf ffmpeg*
  fi
fi
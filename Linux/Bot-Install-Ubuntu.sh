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
    if ! dpkg -s xz-utils wget curl &> /dev/null; then
        echo -e ${yellow}安装必要工具...${background}
        until apt install -y xz-utils wget curl
        do
            echo -e ${red}工具安装失败，3秒后重试${background}
            sleep 3s
        done
    fi
}
ensure_deps

# 架构判断（适配 arm64/aarch64 和 x86_64/amd64）
check_arch() {
    local machine=$(uname -m)
    if [[ "$machine" == "arm64" || "$machine" == "aarch64" ]]; then
        ARCH="linux-arm64"
        NODE_URL="https://npmmirror.com/mirrors/node/v22.18.0/node-v22.18.0-linux-arm64.tar.xz"
        NODE_FILE="node-v22.18.0-linux-arm64.tar.xz"
        echo -e ${green}检测到 arm64 架构，使用指定版本：v22.18.0${background}
    elif [[ "$machine" == "x86_64" || "$machine" == "amd64" ]]; then
        ARCH="linux-x64"
        NODE_URL="https://npmmirror.com/mirrors/node/v22.18.0/node-v22.18.0-linux-x64.tar.xz"
        NODE_FILE="node-v22.18.0-linux-x64.tar.xz"
        echo -e ${green}检测到 x86_64 架构，使用指定版本：v22.18.0${background}
    else
        echo -e ${red}当前架构 $machine 暂不支持${background}
        echo -e ${yellow}请手动下载对应架构的版本：https://npmmirror.com/mirrors/node/${background}
        exit 1
    fi
}

# 检查已安装的 Node.js
check_node() {
    if [ -x "$(command -v node)" ]; then
        echo -e ${green}已安装 Node.js：$(node -v)${background}
        return 0
    else
        return 1
    fi
}

# 从对应架构链接安装 Node.js
install_node() {
    echo -e ${yellow}开始下载 Node.js（${ARCH}）：${NODE_URL}${background}
    i=1
    until wget -O ${NODE_FILE} -c ${NODE_URL}
    do
        if [ $i -ge 3 ]; then
            echo -e ${red}下载失败，尝试手动安装${background}
            manual_node_install
            return
        fi
        i=$((i+1))
        echo -e ${red}下载失败，3秒后重试（第 $i 次）${background}
        sleep 3s
    done

    # 安装（解压到 /usr/local）
    echo -e ${yellow}解压安装...${background}
    sudo tar -xJf ${NODE_FILE} -C /usr/local --strip-components=1
    rm -f ${NODE_FILE}

    # 验证安装
    if [ -x "$(command -v node)" ]; then
        echo -e ${green}Node.js（${ARCH}）安装成功：$(node -v)${background}
    else
        echo -e ${red}安装失败，尝试手动安装${background}
        manual_node_install
    fi
}

# Node.js 手动安装指引
manual_node_install() {
    echo -e ${white}=========================${background}
    echo -e ${yellow}请执行以下步骤手动安装 Node.js（${ARCH}）：${background}
    echo -e 1. 下载文件：${NODE_URL}
    echo -e 2. 上传到当前目录
    echo -e 3. 运行命令：sudo tar -xJf ${NODE_FILE} -C /usr/local --strip-components=1
    echo -e ${white}=========================${background}
    exit 1
}

# 安装 ffmpeg（支持 arm64 和 x86_64）
install_ffmpeg() {
    local machine=$(uname -m)
    local static_url
    if [[ "$machine" == "arm64" || "$machine" == "aarch64" ]]; then
        static_url="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
    elif [[ "$machine" == "x86_64" || "$machine" == "amd64" ]]; then
        static_url="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
    else
        echo -e ${red}当前架构 $machine 暂不支持自动安装 ffmpeg${background}
        manual_ffmpeg_install
        return
    fi

    echo -e ${yellow}尝试下载 ffmpeg 静态版本：${static_url}${background}
    if wget -O ffmpeg.tar.xz -c ${static_url}; then
        mkdir -p ffmpeg && tar -xJf ffmpeg.tar.xz -C ffmpeg --strip-components=1
        chmod +x ffmpeg/ffmpeg ffmpeg/ffprobe
        sudo mv -f ffmpeg/ffmpeg /usr/local/bin/ffmpeg
        sudo mv -f ffmpeg/ffprobe /usr/local/bin/ffprobe
        rm -rf ffmpeg ffmpeg.tar.xz
        echo -e ${green}ffmpeg（${machine}）安装成功${background}
    else
        echo -e ${red}ffmpeg 下载失败，请手动安装${background}
        manual_ffmpeg_install
    fi
}

# ffmpeg 手动安装指引
manual_ffmpeg_install() {
    local machine=$(uname -m)
    local static_url
    if [[ "$machine" == "arm64" || "$machine" == "aarch64" ]]; then
        static_url="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
    elif [[ "$machine" == "x86_64" || "$machine" == "amd64" ]]; then
        static_url="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
    else
        static_url="https://johnvansickle.com/ffmpeg/releases/"
    fi

    echo -e ${white}=========================${background}
    echo -e ${yellow}请执行以下步骤手动安装 ffmpeg（${machine}）：${background}
    echo -e 1. 下载文件：${static_url}
    echo -e 2. 解压：tar -xJf ffmpeg-release-*-static.tar.xz
    echo -e 3. 进入解压目录，运行：${background}
    echo -e "   chmod +x ffmpeg ffprobe"
    echo -e "   sudo mv ffmpeg /usr/local/bin/ffmpeg"
    echo -e "   sudo mv ffprobe /usr/local/bin/ffprobe"
    echo -e ${white}=========================${background}
    exit 1
}

# 主逻辑
if ! check_node; then
    check_arch
    install_node
fi

# 安装 chromium（保持不变）
if ! dpkg -s chromium-browser >/dev/null 2>&1
then
    echo -e ${yellow}安装 chromium 浏览器（${ARCH}）${background}
    until bash <(curl -sL https://gitee.com/baihu433/chromium/raw/master/chromium.sh)
    do
        echo -e ${red}安装失败 3 秒后重试${background}
        sleep 3s
    done
fi

# 安装中文字体（保持不变）
if ! dpkg -s fonts-wqy-zenhei fonts-wqy-microhei >/dev/null 2>&1
then
    echo -e ${yellow}安装中文字体包${background}
    until apt install -y fonts-wqy*
    do
        echo -e ${red}安装失败 3 秒后重试${background}
        sleep 3s
    done
fi

# 安装 ffmpeg（使用新的安装函数）
if [ ! -x "/usr/local/bin/ffmpeg" ];then
    echo -e ${yellow}开始安装 ffmpeg（${ARCH}）${background}
    install_ffmpeg
fi
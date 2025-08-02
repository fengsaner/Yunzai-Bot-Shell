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

# 从arm64专用链接安装Node.js
install_node() {
    echo -e ${yellow}开始下载Node.js（arm64）：${NODE_URL}${background}
    i=1
    until wget -O ${NODE_FILE} -c ${NODE_URL}
    do
        if [ $i -ge 3 ]; then
            echo -e ${red}下载失败，尝试手动安装${background}
            manual_node_install
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
        manual_node_install
    fi
}

# Node.js手动安装指引（arm64专用）
manual_node_install() {
    echo -e ${white}=========================${background}
    echo -e ${yellow}请执行以下步骤手动安装Node.js（arm64）：${background}
    echo -e 1. 下载文件：${NODE_URL}
    echo -e 2. 上传到当前目录
    echo -e 3. 运行命令：sudo tar -xJf ${NODE_FILE} -C /usr/local --strip-components=1
    echo -e ${white}=========================${background}
    exit 1
}

# 安装ffmpeg（修复404问题，使用多重备用链接）
install_ffmpeg() {
    local ffmpeg_file="ffmpeg-linux-arm64"
    local ffprobe_file="ffprobe-linux-arm64"
    
    # 国内镜像备用链接列表（arm64专用）
    local ffmpeg_mirrors=(
        "https://npmmirror.com/mirrors/ffmpeg/release/${ffmpeg_file}"
        "https://mirrors.tuna.tsinghua.edu.cn/ffmpeg/releases/${ffmpeg_file}"
        "https://mirror.iscas.ac.cn/ffmpeg/releases/${ffmpeg_file}"
    )
    
    # 尝试国内镜像下载
    local success=0
    for mirror in "${ffmpeg_mirrors[@]}"; do
        echo -e ${yellow}尝试从镜像下载ffmpeg：${mirror}${background}
        if wget -O ${ffmpeg_file} -c ${mirror}; then
            # 同步下载ffprobe
            wget -O ${ffprobe_file} -c $(echo ${mirror} | sed "s/ffmpeg/ffprobe/")
            success=1
            break
        fi
    done
    
    # 如果国内镜像失败，尝试官方静态编译版本
    if [ $success -eq 0 ]; then
        echo -e ${yellow}国内镜像失败，尝试官方静态版本${background}
        local static_url="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
        if wget -O ffmpeg.tar.xz -c ${static_url}; then
            mkdir -p ffmpeg && tar -xJf ffmpeg.tar.xz -C ffmpeg --strip-components=1
            mv ffmpeg/ffmpeg ${ffmpeg_file}
            mv ffmpeg/ffprobe ${ffprobe_file}
            rm -rf ffmpeg ffmpeg.tar.xz
            success=1
        fi
    fi
    
    # 验证并安装
    if [ $success -eq 1 ] && [ -f "${ffmpeg_file}" ] && [ -f "${ffprobe_file}" ]; then
        chmod +x ${ffmpeg_file} ${ffprobe_file}
        sudo mv -f ${ffmpeg_file} /usr/local/bin/ffmpeg
        sudo mv -f ${ffprobe_file} /usr/local/bin/ffprobe
        echo -e ${green}ffmpeg（arm64）安装成功${background}
    else
        echo -e ${red}ffmpeg下载失败，请手动安装${background}
        manual_ffmpeg_install
    fi
}

# ffmpeg手动安装指引
manual_ffmpeg_install() {
    echo -e ${white}=========================${background}
    echo -e ${yellow}请执行以下步骤手动安装ffmpeg（arm64）：${background}
    echo -e 1. 下载文件：https://npmmirror.com/mirrors/ffmpeg/release/ffmpeg-linux-arm64
    echo -e 2. 下载文件：https://npmmirror.com/mirrors/ffmpeg/release/ffprobe-linux-arm64
    echo -e 3. 上传到当前目录
    echo -e 4. 运行命令：${background}
    echo -e "   chmod +x ffmpeg-linux-arm64 ffprobe-linux-arm64"
    echo -e "   sudo mv ffmpeg-linux-arm64 /usr/local/bin/ffmpeg"
    echo -e "   sudo mv ffprobe-linux-arm64 /usr/local/bin/ffprobe"
    echo -e ${white}=========================${background}
    exit 1
}

# 主逻辑
if ! check_node; then
    check_arch
    install_node
fi

# 安装chromium（保持不变）
if ! dpkg -s chromium-browser >/dev/null 2>&1
then
    echo -e ${yellow}安装chromium浏览器（arm64）${background}
    until bash <(curl -sL https://gitee.com/baihu433/chromium/raw/master/chromium.sh)
    do
        echo -e ${red}安装失败 3秒后重试${background}
        sleep 3s
    done
fi

# 安装中文字体（保持不变）
if ! dpkg -s fonts-wqy-zenhei fonts-wqy-microhei >/dev/null 2>&1
then
    echo -e ${yellow}安装中文字体包${background}
    until apt install -y fonts-wqy*
    do
        echo -e ${red}安装失败 3秒后重试${background}
        sleep 3s
    done
fi

# 安装ffmpeg（使用新的安装函数）
if [ ! -x "/usr/local/bin/ffmpeg" ];then
    echo -e ${yellow}开始安装ffmpeg（arm64）${background}
    install_ffmpeg
fi

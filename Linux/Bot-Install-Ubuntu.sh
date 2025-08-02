#!/bin/env bash
export red="\033[31m"
export green="\033[32m"
export yellow="\033[33m"
export blue="\033[34m"
export purple="\033[35m"
export cyan="\033[36m"
export white="\033[37m"
export background="\033[0m"

# 镜像判断（保留原有逻辑）
if ping -c 1 gitee.com > /dev/null 2>&1
then
  GitMirror="gitee.com"
elif ping -c 1 github.com > /dev/null 2>&1
then
  GitMirror="github.com"
else
  GitMirror="github.com"
  echo -e ${yellow}警告：Gitee和GitHub均无法ping通，默认使用GitHub源${background}
fi

# 安装依赖（保留原有逻辑）
if ! dpkg -s xz-utils >/dev/null 2>&1
then
    echo -e ${yellow}安装xz解压工具${background}
    until apt install -y xz-utils
    do
        echo -e ${red}安装失败 3秒后重试${background}
        sleep 3s
    done
fi

if ! dpkg -s chromium-browser >/dev/null 2>&1
then
    echo -e ${yellow}安装chromium浏览器${background}
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

# 检查已安装的Node.js版本
if [ -x "$(command -v node)" ]
then
    Nodsjs_Version=$(node -v | cut -d '.' -f1)
    echo -e ${green}已安装Node.js版本：${Nodsjs_Version}${background}
fi

# 架构判断（保留原有逻辑）
case $(uname -m) in
    x86_64|amd64)
    ARCH=linux-x64  # Node.js官方架构命名（如linux-x64）
    ARCH2=amd64     # ffmpeg架构命名
;;
    arm64|aarch64)
    ARCH=linux-arm64
    ARCH2=arm64
;;
*)
    echo ${red}不支持的架构：$(uname -m)${background}
    exit 1
;;
esac

# 核心修复：改用Node.js官方API获取版本，避免依赖网页结构
function get_node_version() {
    local major_version=$1  # 主版本（v16或v18）
    # 从官方API获取该主版本下的最新稳定版
    # API返回所有版本的JSON列表，筛选出指定主版本的最新版
    version_info=$(curl -s https://nodejs.org/dist/index.json | grep -E "\"version\": \"${major_version}\." | head -n 1)
    if [ -z "$version_info" ]; then
        echo -e ${red}无法获取${major_version}版本列表${background}
        exit 1
    fi
    # 从JSON中提取版本号（如v18.20.3）
    echo $(echo $version_info | grep -oP '"version": "\K[^"]+')
}

function node_install() {
    # 根据系统选择主版本（简化逻辑，避免依赖/etc/issue判断）
    local major_version=$1
    echo -e ${yellow}获取${major_version}最新稳定版...${background}
    local full_version=$(get_node_version $major_version)
    if [ -z "$full_version" ]; then
        echo -e ${red}获取${major_version}版本失败${background}
        exit 1
    fi
    echo -e ${green}将安装Node.js版本：${full_version}${background}

    # 构建下载链接（官方地址，稳定可靠）
    local base_url="https://nodejs.org/dist"
    local NodeJS_URL="${base_url}/${full_version}/${full_version}-${ARCH}.tar.xz"

    # 验证链接有效性
    echo -e ${yellow}验证下载链接：${NodeJS_URL}${background}
    if ! curl -s --head "$NodeJS_URL" | grep -q "200 OK"; then
        echo -e ${red}链接无效：${NodeJS_URL}${background}
        exit 1
    fi

    # 下载并安装
    echo -e ${yellow}开始下载Node.js...${background}
    i=1
    until wget -O node.tar.xz -c "$NodeJS_URL"
    do
        if [ $i -ge 3 ]; then
            echo -e ${red}下载失败次数过多，退出${background}
            exit 1
        fi
        i=$((i+1))
        echo -e ${red}下载失败，3秒后重试（第$i次）${background}
        sleep 3s
    done

    # 解压到/usr/local（标准安装路径）
    echo -e ${yellow}解压并安装...${background}
    sudo tar -xJf node.tar.xz -C /usr/local --strip-components=1
    rm -f node.tar.xz

    # 验证安装
    if node -v &> /dev/null; then
        echo -e ${green}Node.js安装成功：$(node -v)${background}
    else
        echo -e ${red}Node.js安装失败${background}
        exit 1
    fi
}

# 安装逻辑：如果已安装符合要求的版本则跳过
if ! [[ "$Nodsjs_Version" == "v16" || "$Nodsjs_Version" == "v18" ]]; then
    echo -e ${yellow}需要安装Node.js（v16或v18）${background}
    # 简化版本选择：优先v18，失败则尝试v16
    if ! node_install "v18"; then
        echo -e ${yellow}尝试安装v16版本...${background}
        node_install "v16"
    fi
fi

# ffmpeg安装部分（保留原有逻辑）
if [ ! -x "/usr/local/bin/ffmpeg" ];then
  if [ "${GitMirror}" == "github.com" ]
  then
    if [ ! -d ffmpeg ];then
      mkdir ffmpeg
    fi
    ffmpegURL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-${ARCH2}-static.tar.xz"
    wget -O ffmpeg.tar.xz -c ${ffmpegURL}
    pv ffmpeg.tar.xz | tar -Jxf - -C ffmpeg
    chmod +x ffmpeg/$(ls ffmpeg)/*
    mv -f ffmpeg/$(ls ffmpeg)/ffmpeg /usr/local/bin/ffmpeg
    mv -f ffmpeg/$(ls ffmpeg)/ffprobe /usr/local/bin/ffprobe
    rm -rf ffmpeg*
  elif [ "${GitMirror}" == "gitee.com" ]
  then
    echo -e ${yellow}安装ffmpeg${background}
    ffmpeg_URL="https://registry.npmmirror.com/-/binary/ffmpeg-static/b6.0/"
    wget -O ffmpeg -c ${ffmpeg_URL}/ffmpeg-linux-${ARCH1}
    wget -O ffprobe -c ${ffmpeg_URL}/ffprobe-linux-${ARCH1}
    chmod +x ffmpeg ffprobe
    mv -f ffmpeg /usr/local/bin/ffmpeg
    mv -f ffprobe /usr/local/bin/ffprobe
  fi
fi
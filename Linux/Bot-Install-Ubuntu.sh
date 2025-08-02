#!/bin/env bash
export red="\033[31m"
export green="\033[32m"
export yellow="\033[33m"
export blue="\033[34m"
export purple="\033[35m"
export cyan="\033[36m"
export white="\033[37m"
export background="\033[0m"

# 确保基础工具已安装
ensure_deps() {
    if ! dpkg -s curl wget xz-utils &> /dev/null; then
        echo -e ${yellow}安装必要工具...${background}
        until apt install -y curl wget xz-utils
        do
            echo -e ${red}工具安装失败，3秒后重试${background}
            sleep 3s
        done
    fi
}
ensure_deps

# 架构判断（严格对应Node.js镜像命名）
case $(uname -m) in
    x86_64|amd64)
    ARCH=linux-x64
    ARCH2=amd64
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

# 检查已安装Node.js版本
check_node() {
    if [ -x "$(command -v node)" ]; then
        local ver=$(node -v | cut -d '.' -f1)
        if [[ $ver == "v16" || $ver == "v18" ]]; then
            echo -e ${green}已安装符合要求的Node.js：$(node -v)${background}
            return 0  # 已安装且符合要求
        else
            echo -e ${yellow}已安装Node.js版本不符合要求（需v16/v18）${background}
            return 1
        fi
    else
        echo -e ${yellow}未检测到Node.js${background}
        return 1
    fi
}

# 核心：使用国内镜像+固定版本，避免API依赖
install_node() {
    local major_ver=$1
    # 国内镜像（淘宝Node.js镜像，稳定可靠）
    local mirror="https://registry.npmmirror.com/-/binary/node"
    
    # 固定已知稳定版本（避免动态获取失败）
    declare -A fixed_versions=(
        ["v18"]="v18.20.2"
        ["v16"]="v16.20.2"
    )
    local full_ver=${fixed_versions[$major_ver]}
    local url="${mirror}/${full_ver}/${full_ver}-${ARCH}.tar.xz"

    echo -e ${yellow}准备安装Node.js ${full_ver}（${ARCH}）${background}
    echo -e ${cyan}下载地址：${url}${background}

    # 下载
    i=1
    until wget -O node.tar.xz -c "$url"
    do
        if [ $i -ge 3 ]; then
            echo -e ${red}下载失败次数过多，尝试备用链接...${background}
            # 备用链接：官方地址（最后的 fallback）
            url="https://nodejs.org/dist/${full_ver}/${full_ver}-${ARCH}.tar.xz"
            echo -e ${cyan}尝试备用地址：${url}${background}
            wget -O node.tar.xz -c "$url" || {
                echo -e ${red}所有链接均失败，无法安装${background}
                exit 1
            }
        fi
        i=$((i+1))
        echo -e ${red}下载失败，3秒后重试（第$i次）${background}
        sleep 3s
    done

    # 解压安装（强制覆盖旧版本）
    echo -e ${yellow}解压并安装...${background}
    sudo rm -rf /usr/local/lib/node_modules  # 清理可能的残留
    sudo tar -xJf node.tar.xz -C /usr/local --strip-components=1
    rm -f node.tar.xz

    # 验证
    if node -v | grep -q "${full_ver}"; then
        echo -e ${green}Node.js ${full_ver} 安装成功${background}
        return 0
    else
        echo -e ${red}Node.js 安装失败（版本不匹配）${background}
        return 1
    fi
}

# 主逻辑：优先v18，失败则v16
if ! check_node; then
    echo -e ${yellow}开始安装Node.js...${background}
    if ! install_node "v18"; then
        echo -e ${yellow}v18安装失败，尝试v16...${background}
        install_node "v16" || {
            echo -e ${red}所有版本安装失败，请手动安装：${background}
            echo -e ${cyan}推荐地址：https://registry.npmmirror.com/-/binary/node/${background}
            exit 1
        }
    fi
fi

# 以下为原有其他工具安装逻辑（保持不变）
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

if [ ! -x "/usr/local/bin/ffmpeg" ];then
  if ping -c 1 gitee.com > /dev/null 2>&1
  then
    echo -e ${yellow}安装软件 ffmpeg${background}
    ffmpeg_URL=https://registry.npmmirror.com/-/binary/ffmpeg-static/b6.0/
    wget -O ffmpeg -c ${ffmpeg_URL}/ffmpeg-linux-${ARCH1}
    wget -O ffprobe -c ${ffmpeg_URL}/ffprobe-linux-${ARCH1}
    chmod +x ffmpeg ffprobe
    mv -f ffmpeg /usr/local/bin/ffmpeg
    mv -f ffprobe /usr/local/bin/ffprobe
  else
    if [ ! -d ffmpeg ];then
      mkdir ffmpeg
    fi
    ffmpegURL=https://johnvansickle.com/ffmpeg/releases/
    ffmpegURL=${ffmpegURL}ffmpeg-release-${ARCH2}-static.tar.xz
    wget -O ffmpeg.tar.xz -c ${ffmpegURL}
    pv ffmpeg.tar.xz | tar -Jxf - -C ffmpeg
    chmod +x ffmpeg/$(ls ffmpeg)/*
    mv -f ffmpeg/$(ls ffmpeg)/ffmpeg /usr/local/bin/ffmpeg
    mv -f ffmpeg/$(ls ffmpeg)/ffprobe /usr/local/bin/ffprobe
    rm -rf ffmpeg*
  fi
fi
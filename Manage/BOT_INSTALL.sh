#!/bin/env bash

# 只保留GitHub的判断，移除Gitee相关配置
if ping -c 1 github.com > /dev/null 2>&1
then
  # 直接访问GitHub官方地址
  URL="https://raw.githubusercontent.com/fengsaner/Yunzai-Bot-Shell/master/Linux/Bot-Install-"
else
  # GitHub访问失败时使用镜像地址
  URL="https://dir.fengsaner.xyz/https://raw.githubusercontent.com/fengsaner/Yunzai-Bot-Shell/master/Linux/Bot-Install-"
fi
Arch_Script="${URL}ArchLinux.sh"
Kernel_Script="${URL}CentOS.sh"
Ubuntu_Script="${URL}Ubuntu.sh"
Debian_Script="${URL}Debian.sh"
if grep -q -E -i Arch /etc/issue && [ -x /usr/bin/pacman ];then
    bash <(curl -sL ${Arch_Script})
elif grep -q -E -i Kernel /etc/issue && [ -x /usr/bin/dnf ];then
    echo -e ${red}暂时放弃对centos的支持${background}
    exit
    bash <(curl -sL ${Kernel_Script})
elif grep -q -E -i Kernel /etc/issue && [ -x /usr/bin/yum ];then
    echo -e ${red}暂时放弃对centos的支持${background}
    exit
    bash <(curl -sL ${Kernel_Script})
elif grep -q -E -i Ubuntu /etc/issue && [ -x /usr/bin/apt ];then
    bash <(curl -sL ${Ubuntu_Script})
elif grep -q -E -i Debian /etc/issue && [ -x /usr/bin/apt ];then
    bash <(curl -sL ${Debian_Script})
elif grep -q -E -i Arch /etc/os-release && [ -x /usr/bin/pacman ];then
    bash <(curl -sL ${Arch_Script})
elif grep -q -E -i CentOS /etc/os-release && [ -x /usr/bin/dnf ];then
    echo -e ${red}暂时放弃对centos的支持${background}
    exit
    bash <(curl -sL ${Kernel_Script})
elif grep -q -E -i CentOS /etc/os-release && [ -x /usr/bin/yum ];then
    echo -e ${red}暂时放弃对centos的支持${background}
    exit
    bash <(curl -sL ${Kernel_Script})
elif grep -q -E -i Ubuntu /etc/os-release && [ -x /usr/bin/apt ];then
    bash <(curl -sL ${Ubuntu_Script})
elif grep -q -E -i Debian /etc/os-release && [ -x /usr/bin/apt ];then
    bash <(curl -sL ${Debian_Script})
fi
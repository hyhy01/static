#!/bin/bash

#========================================================
#   System Required: CentOS 7+ / Debian 8+ / Ubuntu 16+ /
#     Arch 未测试
#   Description: 哪吒监控安装脚本
#   Github: https://github.com/naiba/nezha
#========================================================

NZ_BASE_PATH="/usr/local/trojan-go"
NZ_AGENT_SERVICE="/etc/systemd/system/trojan-go.service"
NZ_VERSION="v0.10.6"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
export PATH=$PATH:/usr/local/bin

os_arch=""

pre_check() {
    command -v systemctl >/dev/null 2>&1
    if [[ $? != 0 ]]; then
        echo "不支持此系统：未找到 systemctl 命令"
        exit 1
    fi

    # check root
    [[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

    ## os_arch
    if [[ $(uname -m | grep 'x86_64') != "" ]]; then
        os_arch="amd64"
    elif [[ $(uname -m | grep 'i386\|i686') != "" ]]; then
        os_arch="386"
    elif [[ $(uname -m | grep 'arm64\|aarch64\|armv8b\|armv8l') != "" ]]; then
        os_arch="arm64"
    elif [[ $(uname -m | grep 'arm') != "" ]]; then
        os_arch="arm"
    elif [[ $(uname -m | grep 's390x') != "" ]]; then
        os_arch="s390x"
    elif [[ $(uname -m | grep 'riscv64') != "" ]]; then
        os_arch="riscv64"
    fi

    ## China_IP
    if [[ -z "${CN}" ]]; then
        if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
            echo "根据ipapi.co提供的信息，当前IP可能在中国"
            read -e -r -p "是否选用中国镜像完成安装? [Y/n] " input
            case $input in
            [yY][eE][sS] | [yY])
                echo "使用中国镜像"
                CN=true
                ;;

            [nN][oO] | [nN])
                echo "不使用中国镜像"
                ;;
            *)
                echo "使用中国镜像"
                CN=true
                ;;
            esac
        fi
    fi

    if [[ -z "${CN}" ]]; then
        GITHUB_RAW_URL="raw.githubusercontent.com/p4gefau1t/trojan-go/master"
        GITHUB_URL="github.com"
    else
        GITHUB_RAW_URL="jihulab.com/p4gefau1t/trojan-go/-/raw/master"
        GITHUB_URL="dn-dao-github-mirror.daocloud.io"
    fi
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -e -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -e -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}


before_show_menu() {
    echo && echo -n -e "${yellow}* 按回车返回主菜单 *${plain}" && read temp
    show_menu
}

install_base() {
    (command -v curl >/dev/null 2>&1 && command -v wget >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1) ||
        (install_soft curl wget unzip)
}

install_soft() {
    # Arch官方库不包含selinux等组件
    (command -v yum >/dev/null 2>&1 && yum install epel-release -y)
    (command -v yum >/dev/null 2>&1 && yum install $* -y) ||
        (command -v apt >/dev/null 2>&1 && apt update && apt install $* -y) ||
        (command -v pacman >/dev/null 2>&1 && pacman -Syu $*) ||
        (command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install $* -y)
}



install() {
    install_base

    echo -e "> 安装监控trojan-go"

    echo -e "正在获取trojan-go版本号"

    local version=$(curl -m 10 -sL "https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    if [ ! -n "$version" ]; then
        version=$(curl -m 10 -sL "https://fastly.jsdelivr.net/gh/p4gefau1t/trojan-go/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/naiba\/nezha@/v/g')
    fi
    if [ ! -n "$version" ]; then
        version=$(curl -m 10 -sL "https://gcore.jsdelivr.net/gh/p4gefau1t/trojan-go/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/naiba\/nezha@/v/g')
    fi

    if [ ! -n "$version" ]; then
        echo -e "获取版本号失败，请检查本机能否链接 https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest"
        return 0
    else
        echo -e "当前最新版本为: ${version}"
    fi

    # 哪吒监控文件夹
    mkdir -p $NZ_BASE_PATH
    chmod 777 -R $NZ_BASE_PATH

    echo -e "正在下载监控端"
    wget -t 2 -T 10 -O trojan-go-linux-${os_arch}.zip https://${GITHUB_URL}/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-${os_arch}.zip >/dev/null 2>&1
    echo "https://${GITHUB_URL}/p4gefau1t/trojan-go/releases/download/${version}/trojan-go-linux-${os_arch}.zip"
    if [[ $? != 0 ]]; then
        echo -e "${red}Release 下载失败，请检查本机能否连接 ${GITHUB_URL}${plain}"
        return 0
    fi
    
    
    mv trojan-go-linux-${os_arch}.zip $NZ_BASE_PATH
    cd $NZ_BASE_PATH
    unzip -qo trojan-go-linux-${os_arch}.zip
    if [[ $? != 0 ]]; then
        echo -e "${red}解压失败"
        exit 1
    fi
    #TODO 配置
    if [ $# -ge 6 ]; then
        modify_config "$@"
    else
        modify_config 0
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}
modify_config() {
    echo -e "> 修改trojan-go配置"

    if [ $# -lt 6 ]; then
            read -ep "请输入服务器连接地址: " domain &&
            read -ep "请输入服务器连接端口: " port &&
            read -ep "请输入sni" sni &&
            read -ep "请输入ws_path" ws_path &&
            read -ep "请输入ws_host: " ws_host
            read -ep "请输入password: " password
            read -ep "请输入ss_password: " ss_password
        if [[ -z "${domain}" || -z "${sni}" || -z "${ws_path}" || -z "${ws_host}" || -z "${password}" || -z "${ss_password}" ]]; then
            echo -e "${red}所有选项都不能为空${plain}"
            before_show_menu
            return 1
        fi
    else
        domain=$1
        port=$2
        sni=$3
        ws_path=$4
        ws_host=$5
        password=$6
        ss_password=$7
    fi

    #修改client.yaml
    echo "
    run-type: client
    local-addr: 0.0.0.0
    local-port: 24966
    remote-addr: $domain
    remote-port: $port
    password:
        - $password
    ssl:
        sni: $sni
        verify: false
    mux:
        enabled: false
    router:
        enabled: true
        bypass: ['geoip:cn', 'geoip:private', 'geosite:cn', 'geosite:geolocation-cn']
        block: ['geosite:category-ads']
        proxy: ['geosite:geolocation-!cn']
        default_policy: proxy
        geoip: geoip.dat
        geosite: geosite.dat
    websocket:
      enabled: true
      path: $ws_path
      host: $ws_host
    shadowsocks: 
      enabled: true
      method: AES-128-GCM
      password: $ss_password
    " >  $NZ_BASE_PATH/client.yaml
    echo "
    [Unit]
    Description=Trojan-Go - An unidentifiable mechanism that helps you bypass GFW
    Documentation=https://p4gefau1t.github.io/trojan-go/
    After=network.target nss-lookup.target

    [Service]
    User=nobody
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
    AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
    NoNewPrivileges=true
    ExecStart=/usr/local/trojan-go/trojan-go -config /usr/local/trojan-go/client.yaml
    Restart=on-failure
    RestartSec=10s
    LimitNOFILE=infinity

    [Install]
    WantedBy=multi-user.target
    " >  $NZ_AGENT_SERVICE


    echo -e "trojan-go配置 ${green}修改成功，请稍等重启生效${plain}"

    systemctl daemon-reload
    systemctl enable trojan-go
    systemctl restart trojan-go
    if [[ $? != 0 ]]; then
        echo -e "${red}启动trojan-go失败"
        exit 1
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    echo -e "> 获取trojan-go日志"

    journalctl -xf -u trojan-go.service

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

uninstall() {
    echo -e "> 卸载trojan-go"

    systemctl disable trojan-go.service
    systemctl stop trojan-go.service
    rm -rf $NZ_AGENT_SERVICE
    systemctl daemon-reload

    rm -rf $NZ_BASE_PATH


    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    echo -e "> 重启trojan-go"

    systemctl restart trojan-go.service

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}


show_usage() {
    echo "trojan-go 管理脚本使用方法: "
    echo "--------------------------------------------------------"
    echo "trojan-go.sh install              - 安装监控trojan-go"
    echo "trojan-go.sh show_log             - 查看trojan-go日志"
    echo "trojan-go.sh uninstall            - 卸载trojan-go"
    echo "trojan-go.sh restart              - 重启trojan-go"
    echo "--------------------------------------------------------"
}

show_menu() {
    echo -e "
    ${green}trojan-go管理脚本${plain} ${red}${NZ_VERSION}${plain}
    ${green}1.${plain} 安装监控trojan-go
    ${green}2.${plain} 查看trojan-go日志
    ${green}3.${plain} 卸载trojan-go
    ${green}4.${plain} 重启trojan-go
    ————————————————-
    ${green}0.${plain}  退出脚本
    "
    echo && read -ep "请输入选择 [0-5]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install
        ;;
    2)
        show_log
        ;;
    3)
        uninstall
        ;;
    4)
        restart
        ;;
    *)
        echo -e "${red}请输入正确的数字 [0-5]${plain}"
        ;;
    esac
}

pre_check

if [[ $# > 0 ]]; then
    case $1 in
    "install")
        shift
        if [ $# -ge 3 ]; then
            install "$@"
        else
            install 0
        fi
        ;;
    "show_log")
        show_log 0
        ;;
    "uninstall")
        uninstall 0
        ;;
    "restart")
        restart 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi

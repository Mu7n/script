#!/bin/bash

set -ue
red(){ echo -e "\e[31m$1\e[0m";}
blue(){ echo -e "\e[34m$1\e[0m";}
purple(){ echo -e "\e[35m$1\e[0m";}
cyan(){ echo -e "\e[36m$1\e[0m";}
readp(){ read -p "$(cyan "$1\n")" $2;}

case $(uname -m) in
  amd64 | x86_64)    arch_sh="64";;
  i386 | i686)       arch_sh="32";;
  *)                 red "未知系统！";;
esac

name_sh="xray"
link_sh="https://github.com/XTLS/Xray-core/releases/download"
api_sh="https://api.github.com/repos/XTLS/Xray-core/releases/latest"
tag_sh="$(curl -s $api_sh | grep 'tag_name' | awk -F '"' '{print $4}')"
file_sh="Xray-linux-${arch_sh}.zip"
url_sh="${link_sh}/${tag_sh}/${file_sh}"
path_sh="/etc/ALLINONE/${name_sh}"
grep_sh="$(ps -ef | grep $name_sh | grep -v grep | awk '{print $8}')"

sh_config(){
  uuid_sh="$(xray uuid)"
  x25519_sh="$(xray x25519 > ${path_sh}/x25519.txt)"
  private_sh="$(awk -F ' ' '{print $2}' ${path_sh}/x25519.txt | awk 'NR==1')"
  public_sh="$(awk -F ' ' '{print $2}' ${path_sh}/x25519.txt | awk 'NR==2')"
  cat > ${path_sh}/config.json << JSON
{
    "log": {
        "loglevel": "warning", // 内容从少到多: "none", "error", "warning", "info", "debug"
        "access": "/${path_sh}/access.log",
        "error": "/${path_sh}/error.log"
    },
    "dns": {
        "servers": [
            "https+local://1.1.1.1/dns-query", // 首选 1.1.1.1 的 DoH 查询，牺牲速度但可防止 ISP 偷窥
            "localhost"
        ]
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "ip": [
                    "geoip:cn"
                ],
                "outboundTag": "block"
            },
            {
                "domain": [
                    "geosite:cn"
                ],
                "outboundTag": "block"
            },
            {
                "domain": [
                    "geosite:category-ads-all"
                ],
                "outboundTag": "block"
            },
            {
                "inboundTag": [
                    "dokodemo-in"
                ],
                "domain": [
                    "speed.cloudflare.com" // 需要和 realitySettings 的 serverNames 保持一致
                ],
                "outboundTag": "direct"
            },
            {
                "inboundTag": [
                    "dokodemo-in"
                ],
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "tag": "dokodemo-in",
            "port": 44344, // 需要和 reality 入站 target 保持一致
            "protocol": "dokodemo-door",
            "settings": {
                "address": "speed.cloudflare.com", // 不被偷跑流量speed.cloudflare.com
                "port": 443,
                "network": "tcp"
            },
            "sniffing": { // 勿动
                "enabled": true,
                "destOverride": [
                    "tls"
                ],
                "routeOnly": true
            }
        },
        {
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid_sh",
                        "flow": ""
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "xhttp",
                "xhttpSettings": {
                    "path": "/speedcloudflarecom"
                },
                "security": "reality",
                "realitySettings": {
                    "target": "127.0.0.1:44344", // 指向前面 dokodemo-door 入站
                    "serverNames": [
                        "speed.cloudflare.com"
                    ],
                    "privateKey": "$private_sh",
                    "shortIds": [
                        "1a2b3c4d5e6f",
                        "a1b2c3d4e5f6"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
JSON
}

sh_service(){
JSON
  cat > /etc/systemd/system/${name_sh}.service << XRAY
[Unit]
Description=$name_sh Service
After=network.target nss-lookup.target

[Service]
ExecStart=${path_sh}/${name_sh} run -c ${path_sh}/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
RuntimeDirectory=$name_sh
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
XRAY
  chmod 644 /etc/systemd/system/${name_sh}.service
  systemctl daemon-reload
  systemctl start $name_sh
  systemctl enable $name_sh
}

sh_file(){
  blue "下载$file_sh"
  curl -OL $url_sh
  blue "提取$file_sh"
  mkdir -p -m 644 $path_sh
  if [ ! -z $grep_sh ]; then pkill -9 $name_sh; fi
  unzip -oj $file_sh -d $path_sh
  rm -rf ${file_sh}
  ln -s ${path_sh}/${name_sh} /usr/local/bin
}

ssh_config(){
  if [ ! -s /etc/ssh/sshd_config.d/AIO.conf ]; then
	readp "请输入SSH端口：" sshport_sh
	purple "SSH端口：$sshport_sh"
	cat > /etc/ssh/sshd_config.d/AIO.conf << SSHD
Port $sshport_sh
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
SSHD
	ufw allow $sshport_sh
	ufw allow 443
	ufw allow 80
	echo "y" | ufw enable
	systemctl restart sshd
  fi
}

purple "\nMu"

if [ -s ${path_sh}/${name_sh} ]; then
  while true; do
    purple "检测到已安装$name_sh。"
	blue "1、升级"
	blue "2、退出"
	readp "请输入选项：" option_sh
	case $option_sh in 1) if [ ! -z $tag_sh ]; then sh_file; sh_config; sh_service; ssh_config; fi; break;; 2) blue "退出。"; break;; *) red "错误，请重新输入！"; continue;; esac
  done
else
  sh_file
  sh_config
  sh_service
  ssh_config
fi

ufw status
service $name_sh status
purple "\nEND！"

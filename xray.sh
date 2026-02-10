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
  x25519_sh="$(xray x25519)"
  private_sh="$(echo "$x25519_sh" | grep 'PrivateKey' | awk '{print $2}')"
  public_sh="$(echo "$x25519_sh" | grep 'Password' | awk '{print $2}')"
  servername_sh="speed.cloudflare.com"
  cat > ${path_sh}/config.json << REALITYXHTTP
{
    "log": {
        "loglevel": "warning",
        "access": "${path_sh}/access.log",
        "error": "${path_sh}/error.log"
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
                    "$servername_sh" // 需要和 realitySettings 的 serverNames 保持一致
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
            "port": 44344, // 需要和 realitySettings 的 target 保持一致
            "protocol": "dokodemo-door",
            "settings": {
                "address": "$servername_sh", // speed.cloudflare.com 不会被偷跑流量，需要和 realitySettings 的 serverNames 保持一致
                "port": 443,
                "network": "tcp"
            },
            "sniffing": { // 重要，勿动
                "enabled": true,
                "destOverride": [
                    "tls"
                ],
                "routeOnly": true
            }
        },
        {
            "listen": "0.0.0.0",
            "port": 44380,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid_sh",
                        "flow": ""
						"level": 0,
						"email": "vless@reality.xhttp"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "xhttp",
                "xhttpSettings": {
                    "path": "/${servername_sh}"
                },
                "security": "reality",
                "realitySettings": {
                    "target": "127.0.0.1:44344", // 指向前面 dokodemo-door 入站
                    "serverNames": [
                        "$servername_sh"
                    ],
                    "privateKey": "$private_sh",
                    "shortIds": [
                        "$shortid_sh"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
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
REALITYXHTTP
  cat > ${path_sh}/config.json << TLSVISION
{
    "log": {
        "loglevel": "warning",
        "access": "${path_sh}/access.log",
        "error": "${path_sh}/error.log"
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
            }
        ]
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid_sh",
                        "flow": "xtls-rprx-vision"
						"level": 0,
						"email": "vless@tls.vision"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": "44381",
                        "xver": 1
                    },
                    {
                        "alpn": "h2",
                        "dest": "44382",
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "rejectUnknownSni": true,
                    "minVersion": "1.2",
                    "certificates": [
                        {
                            "certificateFile": "/etc/letsencrypt/live/${domain_sh}/fullchain.cer",
                            "keyFile": "/etc/letsencrypt/live/${domain_sh}/privkey.pem"
                        }
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
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
    ],
    "policy": {
        "levels": {
            "0": {
                "statsUserUplink": true,
                "statsUserDownlink": true
            }
        }
    }
}
TLSVISION
}

sh_service(){
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

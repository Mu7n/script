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
path="/usr/local/${name_sh}"
grep_sh="$(ps -ef | grep $name_sh | grep -v grep | awk '{print $8}')"
uuid_sh="$(xray uuid)"


download_sh(){
  blue "下载$xray_zip"
	curl -L $xray_url -o $xray_zip
	blue "提取$xray_zip"
	mkdir -p -m 644 $xray_path
	tar xzvf $xray_path
	if [ ! -z $xray_grep ]; then pkill -9 frps; fi
	mv -f Xray-linux-${xray_tag}/{xray,geoip.dat,geosite.dat} ${xray_path}
	rm -rf ${xray_zip} Xray-linux-${xray_tag}
}

xray_config(){
  cat > ${xray_path}/config.json < JSON
{
  "log": {
    "loglevel": "warning", // 内容从少到多: "none", "error", "warning", "info", "debug"
    "access": "/${xray_path}/access.log",
    "error": "/${xray_path}/error.log"
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
          "geoip:private" // 分流条件：geoip 文件内，名为"private"的规则（本地）
        ],
        "outboundTag": "block" // 分流策略：交给出站"block"处理（黑洞屏蔽）
      },
      {
        "ip": ["geoip:cn"],
        "outboundTag": "block" // 防止服务器直连国内
      },
      {
        "domain": [
          "geosite:category-ads-all" // 分流条件：geosite 文件内，名为"category-ads-all"的规则（各种广告域名）
        ],
        "outboundTag": "block" // 分流策略：交给出站"block"处理（黑洞屏蔽）
      }
    ]
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid_sh}",
            "flow": "xtls-rprx-vision",
            "level": 0,
            "email": "xray@vless.xtls"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 80 // 默认回落到防探测的代理
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": "http/1.1",
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/\${domain}/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/\${domain}/privkey.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ]
}
JSON
}

xray_service(){
  cat >/etc/systemd/system/xray.service <<XRAY
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
ExecStart=${xray_path}/xray run -config ${xray_path}/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
RuntimeDirectory=xray
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
  cat >/etc/systemd/system/xray@.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
ExecStart=${xray_path}/xray run -config ${xray_path}/%i.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
RuntimeDirectory=xray-%i
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
XRAY
  chmod 644 /etc/systemd/system/${name_sh}.service /etc/systemd/system/${name_sh}@.service
  systemctl daemon-reload
  systemctl start $name_sh
  systemctl enable $name_sh
}

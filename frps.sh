#!/bin/bash

set -ue
red(){ echo -e "\e[31m$1\e[0m";}
blue(){ echo -e "\e[34m$1\e[0m";}
purple(){ echo -e "\e[35m$1\e[0m";}
cyan(){ echo -e "\e[36m$1\e[0m";}
readp(){ read -p "$(cyan "$1\n")" $2;}

case $(uname -m) in
  x86_64)     arch_sh="amd64";;
  aarch64)    arch_sh="arm64";;
  *)          red "未知系统！";;
esac

name_sh="frps"
link_sh="https://github.com/fatedier/frp/releases/download"
api_sh="https://api.github.com/repos/fatedier/frp/releases/latest"
tag_sh="$(curl -s $api_sh | grep 'tag_name' | awk -F '"' '{print $4}' | cut -c 2-)"
file_sh="frp_${tag_sh}_linux_${arch_sh}.tar.gz"
url_sh="${link_sh}/v${tag_sh}/${file_sh}"
path_sh="/usr/local/${name_sh}"
grep_sh="$(ps -ef | grep $name_sh | grep -v grep | awk '{print $8}')"

sh_config(){
  cat > ${path_sh}/config.toml << TOML
bindAddr = "0.0.0.0"
bindPort = 60443
kcpBindPort = 60443
vhostHTTPPort = 60443
vhostHTTPSPort = 60443

auth.method = "token"
auth.token = "$token_sh"

webServer.addr = "0.0.0.0"
webServer.port = 44380
webServer.user = "$USERNAME"
webServer.password = "$PASSWORD"
#webServer.tls.certFile = "/etc/letsencrypt/live/\${domain_sh}/fullchain.pem"
#webServer.tls.keyFile = "/etc/letsencrypt/live/\${domain_sh}/privkey.pem"
#subDomainHost = "\$domain_sh"

transport.maxPoolCount = 10
transport.tcpKeepalive = 7200
transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 60
transport.heartbeatTimeout = 90

allowPorts = [
  { single = 3000 },
  { single = 16601 },
  { start = 10000, end = 60000 }
]

log.to = "${path_sh}/${name_sh}.log"
log.level = "info"
log.maxDays = 3
TOML
}

sh_service(){
  cat > /etc/systemd/system/${name_sh}.service << FRP
[Unit]
Description=$name_sh Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=${path_sh}/${name_sh} -c ${path_sh}/$config.toml

[Install]
WantedBy=multi-user.target
FRP
  chmod 644 /etc/systemd/system/${name_sh}.service
  systemctl daemon-reload
  systemctl start $name_sh
  systemctl enable $name_sh
}

read_token(){
  readp "请输入username：" USERNAME
  readp "请输入password：" PASSWORD
  token_sh="${USERNAME}${PASSWORD}"
  purple "token：$token_sh"
  while true; do readp "请确认令牌[Yes/No]：" input_sh; case $input_sh in [yY][eE][sS]|[yY]) purple "已确认。"; break;; [nN][oO]|[nN]) blue "请重新输入。"; readp "请输入username：" USERNAME; readp "请输入password：" PASSWORD; token_sh="${USERNAME}${PASSWORD}"; purple "token：$token_sh";; *) red "错误，请重新输入！"; continue;; esac done
}

sh_file(){
  blue "下载$file_sh"
  curl -L $url_sh -o $file_sh
  blue "提取$file_sh"
  mkdir -p $path_sh
  tar xzvf $file_sh
  if [ ! -z $grep_sh ]; then pkill -9 $name_sh; fi
  mv -f frp_${tag_sh}_linux_${arch_sh}/frps ${path_sh}
  rm -rf ${file_sh} frp_${tag_sh}_linux_${arch_sh}
}

sshd_config(){
  if [ ! -s /etc/ssh/sshd_config.d/FLO.conf ]; then
	readp "请输入SSH端口：" sshport_sh
	purple "SSH端口：$sshport_sh"
	cat > /etc/ssh/sshd_config.d/FLO.conf << SSHD
Port $sshport_sh
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
SSHD
	ufw allow $sshport_sh
	ufw allow 60443
	ufw allow 44380
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
	case $option_sh in 1) if [ ! -z $tag_sh ]; then sh_file; read_token; sh_config; sh_service; sshd_config; fi; break;; 2) blue "退出。"; break;; *) red "错误，请重新输入！"; continue;; esac
  done
else
  sh_file
  read_token
  sh_config
  sh_service
  sshd_config
fi

ufw status
service $name_sh status
purple "\nEND！"

#!/bin/bash

set -ue
red(){ echo -e "\e[31m$1\e[0m";}
blue(){ echo -e "\e[34m$1\e[0m";}
purple(){ echo -e "\e[35m$1\e[0m";}
cyan(){ echo -e "\e[36m$1\e[0m";}
readp(){ read -p "$(cyan "$1\n")" $2;}

name_sh="frp"
path_sh="/usr/local/${name_sh}"
grep_sh="$(ps -ef | grep $name_sh | grep -v grep | awk '{print $8}')"
file_sh="https://github.com/fatedier/frp/releases/download"
api_sh="https://api.github.com/repos/fatedier/frp/releases/latest"
tag_sh="$(curl -s $api_sh | grep 'tag_name' | awk -F '"' '{print $4}' | cut -c 2-)"
tar_sh="frp_${tag_sh}_linux_${arch_sh}.tar.gz"
url_sh="${file_sh}/v${tag_sh}/${tar_sh}"


# 检查系统
case $(uname -m) in
  x86_64)     arch_sh="amd64";;
  aarch64)    arch_sh="arm64";;
  *)          red "未知系统！";;
esac

frpsconfig(){
  cat > ${frp_path}/frps.toml << TOML
bindAddr = "0.0.0.0"
bindPort = 60443
kcpBindPort = 60443
vhostHTTPPort = 60443
vhostHTTPSPort = 60443

auth.method = "token"
auth.token = "$frp_token"

webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "$USERNAME"
webServer.password = "$PASSWORD"
#webServer.tls.certFile = "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
#webServer.tls.keyFile = "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
#subDomainHost = "$DOMAIN"

transport.maxPoolCount = 10
transport.tcpKeepalive = 7200
transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 60
transport.heartbeatTimeout = 90

log.to = "${frp_path}/frps.log"
log.level = "info"
log.maxDays = 3

allowPorts = [
  { single = 3000 },
  { single = 16601 },
  { start = 10000, end = 60000 }
]
TOML

  cat > /etc/systemd/system/frps.service << FRPS
[Unit]
Description=Frp Server Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=${frp_path}/frps -c ${frp_path}/frps.toml

[Install]
WantedBy=multi-user.target
FRPS
}

readtoken(){
  readp "请输入username：" USERNAME
	readp "请输入password：" PASSWORD
	TOKEN="${USERNAME}${PASSWORD}"
	purple "TOKEN：$TOKEN"
	while true; do readp "请确认令牌[Yes/No]：" INPUT; case $INPUT in [yY][eE][sS]|[yY]) purple "已确认。"; frpsconfig; break;; [nN][oO]|[nN]) blue "请重新输入。"; readp "请输入username：" USERNAME; readp "请输入password：" PASSWORD; TOKEN="${USERNAME}${PASSWORD}"; purple "TOKEN：$TOKEN";; *) red "错误，请重新输入！"; continue;; esac done
}

frptargz(){

	blue "下载$FRPTAR"
	curl -L $FRPURL -o $FRPTAR
	blue "提取$FRPTAR"
	mkdir -p $FRPPATH
	tar xzvf $FRPTAR
	if [ ! -z $GREP ]; then pkill -9 frps; fi
	mv -f frp_${VER}_linux_${ARCH}/frps ${FRPPATH}
	rm -rf ${FRPTAR} frp_${VER}_linux_${ARCH}
}

frpserver(){
  chmod 644 /etc/systemd/system/frps.service
	systemctl daemon-reload
	systemctl start frps
	systemctl enable frps
}

# Frp
if [ -s ${FRPPATH}/frps ]; then
    while true; do
	    purple "检测到已安装frps。"
		blue "1、升级"
		blue "2、退出"
		readp "请输入选项：" OPTION
		case $OPTION in 1) if [ ! -z $VER ]; then frptargz; readtoken; frpserver; fi; break;; 2) blue "退出。"; break;; *) red "错误，请重新输入！"; continue;; esac
	done
else
    frptargz
	readtoken
	frpserver
fi

# SSH
if [ ! -s /etc/ssh/sshd_config.d/FLO.conf ]; then
#echo -e "\e[32mvim 按下i进入编辑模式 | 按下ecs退出编辑模式 | 输入:wq(!强制)保存并退出，输入:q!退出不保存\e[0m"
#sudo vim /etc/ssh/sshd_config
echo -e "\e[32mPort ***** | PermitRootLogin yes | PubkeyAuthentication yes | PasswordAuthentication no\e[0m"
read -r -p "请输入SSH端口：" sshport
echo -e "SSH端口：\e[35m$sshport\e[0m"

# FLO.conf
cat > /etc/ssh/sshd_config.d/FLO.conf << SSHD
Port $sshport
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
SSHD

# 防火墙
#iptables -A INPUT -p tcp --dport $sshport -j ACCEPT
ufw allow $sshport
ufw allow 443
ufw allow 7000
ufw allow 7500
echo "y" | ufw enable

echo -e "\e[31m如有问题输入systemctl start ssh && systemctl enable ssh && systemctl restart sshd(.service)\e[0m"
systemctl restart sshd
fi

# 状态
ufw status
service frps status

echo -e "\e[35m\nEND！\e[0m"

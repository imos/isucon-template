#!/bin/bash
# Usage:
#   curl 'https://raw.githubusercontent.com/imos/isucon-template/master/base.sh' | bash

set -e -u

################################################################################
# 1. Docker のインストール
################################################################################
if ! which docker; then
  curl -sSL https://get.docker.com/ | sudo sh
fi
sudo service docker restart

################################################################################
# 2. ユーザ ninetan (10001) の準備
################################################################################

# ユーザが存在しなければ追加する
if ! id ninetan; then
  sudo useradd --home-dir=/home/ninetan --create-home --uid=10001 \
      --user-group --shell=/bin/bash ninetan
fi

# ninetan 権限の下で，id_rsa の生成を行い，authorized_keys に追加する
cat <<'EOM' | sudo -u ninetan bash
set -e -u
cd /home/ninetan
mkdir -p .ssh
if [ ! -f ".ssh/id_rsa" ]; then
  ssh-keygen -t 'rsa' -N '' -f '.ssh/id_rsa'
fi
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrHaL3kdZ2RekCdpkie3fsiv2yVyyWRBOO6Q68Kr+tFStRqtF8q1/UoeteUIOxzwKaAmHoaM9PkItdMBki0BLQDimCZwjjbkosritGDMTJXGd21O72mWaTv+nfq+/ishCdt6gdBYXTejvpPJhq8ZMYhTYJZkWqlGO2CKrWcnHHu1HhnValeqNWS5nh8BULOTMKaixjdzXIkWgm8HyiewvqjZXC3tZlfFDErRpiS7SYfJHd4PujjFCNyiVxZ5yOvEGMXQa1UFxQlfX8H+lAr6qObK50osAdUbvjjbhIhMvZT2higSNNtv/yiaLRnLbbOHomObvqxob5TUVdCkazXX3N imos@Moltres' > .ssh/imos.pub
cat .ssh/*.pub > .ssh/authorized_keys
chmod 600 .ssh/authorized_keys

echo 'Host *' > .ssh/config
echo '  UserKnownHostsFile /dev/null' >> .ssh/config
echo '  StrictHostKeyChecking no' >> .ssh/config
EOM
# ninetan が sudo を実行できるようにする
if ! sudo grep ninetan /etc/sudoers; then
  echo 'ninetan ALL=(ALL:ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers
fi

################################################################################
# 3. sysctl.conf の設定
################################################################################

# /etc/sysctl.conf.orig として元のファイルをバックアップしておく．
# ただし，二度目の実行はバックアップを行わず，元のファイルをそのまま残す．
if [ ! -f /etc/sysctl.conf.orig -a -f /etc/sysctl.conf ]; then
  sudo cp /etc/sysctl.conf /etc/sysctl.conf.orig
fi

# 主にネットワークを最適化するための設定
cat <<'EOM' | sudo tee /etc/sysctl.conf
net.core.netdev_max_backlog=32768
net.core.rmem_max = 16777216
net.core.somaxconn=32768
net.core.wmem_max = 16777216
net.ipv4.ip_local_port_range= 10000 65535
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_max_syn_backlog=32768
net.ipv4.tcp_rmem = 4096 349520 16777216
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_tw_recycle=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_slow_start_after_idle=0
net.core.somaxconn=65535
EOM
# 再起動後も有効になるように設定
sudo sysctl -p

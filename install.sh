#!/bin/bash
# ninecontroller を自動起動する設定にします
#
# Usage:
#   curl -L 'https://raw.githubusercontent.com/imos/isucon-template/master/install.sh' | bash

set -e -u

################################################################################
# 1. 基本環境のセットアップ
################################################################################

curl "${TEMPLATE_REPOSITORY:-"https://raw.githubusercontent.com/imos/isucon-template/${TEMPLATE_BRANCH:-"master"}/base.sh"}" | bash
# エディタのカラーリング調整用 → "

################################################################################
# 2. イメージのダウンロード
################################################################################

curl -L "https://storage.googleapis.com/imoz-docker-tokyo/ninecontroller/${IMAGE_BRANCH:-"master"}.tar.gz" | gzip -d | sudo docker load

################################################################################
# 3. ninecontroller の自動起動
################################################################################

sudo mkdir -p '/usr/local/ninecontroller'
if [ ! -f /usr/local/ninecontroller/Dockerfile ]; then
  cat <<'EOM' | sudo tee '/usr/local/ninecontroller/Dockerfile'
FROM imos/ninecontroller
MAINTAINER imos

RUN touch /.foo

CMD /usr/bin/supervisord --nodaemon
EOM
fi

cat <<'EOM' | sudo tee /etc/init.d/ninecontroller
#!/bin/bash
# ninecontroller用init.dスクリプト
# ※ Dockerより後に起動する必要があるので /etc/init.d/docker の優先度を確認すること
#
# chkconfig:   2345 96 04
# description: Daemon for docker.com

start() {
  sudo docker build --tag local/ninecontroller /usr/local/ninecontroller
  sudo docker rm -f ninecontroller || true
  sudo docker run --privileged \
      --volume=/var/run/docker.sock:/var/run/docker.sock \
      --volume=/home/ninetan:/home/ninetan \
      --name=ninecontroller \
      --restart=always \
      --net=host \
      --pid=host \
      --detach \
      local/ninecontroller
}

stop() {
  sudo docker rm -f ninecontroller || true
}

case "$1" in
  start|stop) $1 ;;
  status) sudo docker ps --filter=name=ninecontroller ;;
  restart) start ;;
  *) echo "Usage: $0 {start|stop|restart|status}"; exit 2 ;;
esac

exit $?
EOM
sudo chmod +x /etc/init.d/ninecontroller
if which chkconfig; then
  sudo chkconfig --add ninecontroller
else
  sudo update-rc.d ninecontroller defaults
fi
sudo service ninecontroller restart

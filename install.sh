#!/bin/bash
# ninecontroller を作成します

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

cat <<'EOM' | sudo tee /etc/init.d/ninecontroller
#!/bin/bash
# ninecontroller用init.dスクリプト
# ※ Dockerより後に起動する必要があるので /etc/init.d/docker の優先度を確認すること
#
# chkconfig:   2345 96 04
# description: Daemon for docker.com

start() {
  sudo docker rm -f ninecontroller || true
  sudo docker run --privileged \
      --volume=/var/run/docker.sock:/var/run/docker.sock \
      --volume=/home/ninetan:/home/ninetan \
      --name=ninecontroller \
      --restart=always \
      --net=host \
      --pid=host \
      --detach \
      ninecontroller
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

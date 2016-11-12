#!/bin/bash
# ninecontroller を作成します

set -e -u

################################################################################
# 1. 基本環境のセットアップ
################################################################################

curl "${TEMPLATE_REPOSITORY:-"https://raw.githubusercontent.com/imos/isucon-template/${TEMPLATE_BRANCH:-"master"}/base.sh"}" | bash
# エディタのカラーリング調整用 → "

################################################################################
# 2. gcloud の設定
################################################################################

mkdir -p '/tmp/docker/gcloud'
cat <<'EOM' > '/tmp/docker/gcloud/Dockerfile'
FROM ubuntu:16.04
MAINTAINER imos

RUN apt update && apt install --yes curl python
RUN curl https://sdk.cloud.google.com | \
    CLOUDSDK_INSTALL_DIR=/usr/local CLOUDSDK_CORE_DISABLE_PROMPTS=1 bash
ENV PATH $PATH:/usr/local/google-cloud-sdk/bin
EOM
sudo docker build --tag imos/gcloud /tmp/docker/gcloud

if [ ! -d ~/.config/gcloud ]; then
  gcloud init
fi

################################################################################
# 2. Docker イメージの作成
################################################################################

mkdir -p '/tmp/docker/ninecontroller'
cat <<'EOM' > /tmp/docker/ninecontroller/Dockerfile
FROM ubuntu:16.04
MAINTAINER imos

# sshd のセットアップ．サーバの指紋を早期に確定するために最初に持ってきている．
RUN mkdir -p /var/run/sshd
RUN apt update && apt install --yes openssh-server

# 必要なソフトウェアのインストール
RUN apt update && apt install --yes \
    apt-transport-https ca-certificates curl lxc iptables sudo openjdk-8-jdk \
    unzip git g++-4.9 supervisor
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 100
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 100

RUN curl -sSL https://get.docker.com/ | sh
RUN useradd --home-dir=/home/ninetan --create-home --uid=10001 --user-group \
        --shell=/bin/bash ninetan
RUN echo 'ninetan ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers


RUN curl -L -o /root/installer.sh 'https://github.com/bazelbuild/bazel/releases/download/0.4.0/bazel-0.4.0-installer-linux-x86_64.sh'
RUN bash /root/installer.sh && rm /root/installer.sh

RUN echo '# Bazelrc for GCC' > /etc/bazel.bazelrc
RUN echo 'build --verbose_failures --copt=-fdiagnostics-color=always --copt=-Wno-cpp --copt=-Wno-unused-local-typedefs --copt=-Wno-sign-compare --copt=-Wno-array-bounds' >> /etc/bazel.bazelrc
RUN echo 'test --verbose_failures --test_timeout=3600 --test_output=errors' >> /etc/bazel.bazelrc

# ※ ホストのDockerのAPIバージョンに合わせて変えること
# ホストのAPIバージョンは "docker version" で確認可能
RUN echo 'DOCKER_API_VERSION="1.23"' >> /etc/environment

RUN echo '[program:sshd]' > /etc/supervisor/conf.d/sshd.conf
RUN echo 'command=/usr/sbin/sshd -D -p 2222' >> /etc/supervisor/conf.d/sshd.conf

RUN echo '[program:nined]' > /etc/supervisor/conf.d/nined.conf
RUN echo 'command=/home/ninetan/init.sh' >> /etc/supervisor/conf.d/nined.conf

CMD /usr/bin/supervisord --nodaemon
EOM
sudo docker build --tag imos/ninecontroller /tmp/docker/ninecontroller
sudo docker rm -f ninecontroller || true
sudo docker run --privileged \
    --volume=/var/run/docker.sock:/var/run/docker.sock \
    --volume=/home/ninetan:/home/ninetan \
    --name=ninecontroller \
    --restart=always \
    --net=host \
    --pid=host \
    --detach \
    imos/ninecontroller

sudo docker save imos/ninecontroller | gzip > ~/ninecontroller.tar.gz
sudo docker run \
  --volume=$HOME/.config/gcloud:/root/.config/gcloud \
  --volume=$HOME:/host --rm -it gcloud \
  gsutil cp /host/ninecontroller.tar.gz \
      gs://imoz-docker-tokyo/ninecontroller/experimental.tar.gz

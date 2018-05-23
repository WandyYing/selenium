#== FROM instructions support variables that are declared by
# any ARG instructions that occur before the first FROM
# ref: https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
#
# To overwrite the build args use:
#  docker build ... --build-arg UBUNTU_DATE=20171006
ARG UBUNTU_FLAVOR=xenial
ARG UBUNTU_DATE=20180228

#== Ubuntu xenial is 16.04, i.e. FROM ubuntu:16.04
# Find latest images at https://hub.docker.com/r/library/ubuntu/
# Layer size: ~122 MB
FROM elgalu/selenium:latest

MAINTAINER Ying Jun <Wandy1208@gmail.com>

# https://github.com/docker/docker/pull/25466#discussion-diff-74622923R677
LABEL maintainer "Ying Jun <Wandy1208@gmail.com>"

#==============================
# Locale and encoding settings
#==============================
# TODO: Allow to change instance language OS and Browser level
#  see if this helps: https://github.com/rogaha/docker-desktop/blob/68d7ca9df47b98f3ba58184c951e49098024dc24/Dockerfile#L57
ENV LANG_WHICH en
ENV LANG_WHERE US
ENV ENCODING UTF-8
ENV LANGUAGE ${LANG_WHICH}_${LANG_WHERE}.${ENCODING}
ENV LANG ${LANGUAGE}
# Layer size: small: ~9 MB
# Layer size: small: ~9 MB MB (with --no-install-recommends)
RUN apt -qqy update \
  && apt -qqy --no-install-recommends install \
    language-pack-en \
    tzdata \
    locales \
  && locale-gen ${LANGUAGE} \
  && dpkg-reconfigure --frontend noninteractive locales \
  && apt -qyy autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

#===================
# Timezone settings
#===================
# Full list at https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
#  e.g. "US/Pacific" for Los Angeles, California, USA
# e.g. ENV TZ "US/Pacific"
ENV TZ="Asia/Shanghai"
# Apply TimeZone
# Layer size: tiny: 1.339 MB
RUN echo "Setting time zone to '${TZ}'" \
  && echo "${TZ}" > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata

ENV ROOT_PASSWORD root

RUN apt-get -qqy update \
  && apt-get -qqy --no-install-recommends install \
    python2.7 \
    python-pip \
    python-lxml \
    bash \
    wget \
    curl \
    unzip \
    git

RUN apt-get install -y python-wxgtk3.0

#ssh-server
RUN apt-get -qqy update \
  && apt-get -qqy install -y openssh-server \
        && mkdir /var/run/sshd \
        && echo "root:${ROOT_PASSWORD}" | chpasswd \
        && sed -ri 's/^PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
        && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
        && rm -rf /var/cache/apk/* /tmp/*


# Fixed python-wxgtk2.8 not available issue
# Reference https://askubuntu.com/questions/789302/install-python-wxgtk2-8-on-ubuntu-16-04
# RUN echo "deb http://archive.ubuntu.com/ubuntu wily main universe" | tee /etc/apt/sources.list.d/wily-copies.list \
# apt-get install --reinstall -d `apt-cache depends python-wxgtk2.8  | grep Depends | cut -d: f2 |tr -d "<>"`
#########################################
##    REPOSITORIES AND DEPENDENCIES    ##
#########################################
RUN echo 'deb http://archive.ubuntu.com/ubuntu trusty main universe restricted' > /etc/apt/sources.list && \
    echo 'deb http://archive.ubuntu.com/ubuntu trusty-updates main universe restricted' >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y python-wxgtk2.8 \
    && rm -rf /var/cache/apk/* /tmp/* 

RUN echo 'deb http://cn.archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse' > /etc/apt/sources.list && \
    echo 'deb http://cn.archive.ubuntu.com/ubuntu/ xenial-security main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb http://cn.archive.ubuntu.com/ubuntu/ xenial-updates main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb http://cn.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse' >> /etc/apt/sources.list && \
    ##測試版源
    echo 'deb http://cn.archive.ubuntu.com/ubuntu/ xenial-proposed main restricted universe multiverse' >> /etc/apt/sources.list && \
    # 源碼
    echo 'deb-src http://cn.archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb-src http://cn.archive.ubuntu.com/ubuntu/ xenial-security main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb-src http://cn.archive.ubuntu.com/ubuntu/ xenial-updates main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb-src http://cn.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse' >> /etc/apt/sources.list && \
    ##測試版源
    echo 'deb-src http://cn.archive.ubuntu.com/ubuntu/ xenial-proposed main restricted universe multiverse' >> /etc/apt/sources.list


COPY scripts/ /home/seluser/exec/
##Robot env
# RUN pip install --upgrade pip \
#  && 
RUN pip install --upgrade setuptools
RUN pip install -Ur /home/seluser/exec/requirements.txt 


COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["entrypoint.sh"]

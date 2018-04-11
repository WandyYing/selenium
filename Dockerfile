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
FROM ubuntu:${UBUNTU_FLAVOR}-${UBUNTU_DATE}

#== An ARG declared before a FROM is outside of a build stage,
# so it can’t be used in any instruction after a FROM. To use
# the default value of an ARG declared before the first
# FROM use an ARG instruction without a value inside of a build stage
# ref: https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG UBUNTU_FLAVOR
ARG UBUNTU_DATE

# Docker build debug logging, green colored
RUN printf "\033[1;32mFROM ubuntu:${UBUNTU_FLAVOR}-${UBUNTU_DATE} \033[0m\n"

#== Ubuntu flavors - common
RUN  echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_FLAVOR} main universe\n" > /etc/apt/sources.list \
  && echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_FLAVOR}-updates main universe\n" >> /etc/apt/sources.list \
  && echo "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_FLAVOR}-security main universe\n" >> /etc/apt/sources.list

MAINTAINER Ying Jun <Wandy1208@gmail.com>

# https://github.com/docker/docker/pull/25466#discussion-diff-74622923R677
LABEL maintainer "Ying Jun <Wandy1208@gmail.com>"

# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

# GPG servers aren't too reliable (especially in out test builds)
# so fallback servers are needed
#  ref: https://github.com/nodejs/docker-node/issues/340#issuecomment-321669029
#  ref: http://askubuntu.com/a/235911/134645
#  ref: https://github.com/moby/moby/issues/20022#issuecomment-182169732
# How to remove keys? e.g. sudo apt-key del 2EA8F35793D8809A
RUN set -ex \
  && for key in \
    2EA8F35793D8809A \
    40976EAF437D05B5 \
    3B4FE6ACC0B21F32 \
    A2F683C52980AECF \
    F76221572C52609D \
    58118E89F3A912897C070ADBF76221572C52609D \
  ; do \
    gpg --keyserver keyserver.ubuntu.com --recv-keys "$key" || \
    gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
  done

#========================
# Miscellaneous packages
#========================
# libltdl7        0.3 MB
#   allows to run docker alongside docker
# netcat-openbsd  0.5 MB
#   inlcues `nc` an arbitrary TCP and UDP connections and listens
# pwgen           0.4 MB
#   generates random, meaningless but pronounceable passwords
# bc              0.5 MB
#   An arbitrary precision calculator language
# unzip           0.7 MB
#   uncompress zip files
# bzip2           1.29 MB
#   uncompress bzip files
# apt-utils       1.0 MB
#   commandline utilities related to package management with APT
# net-tools       0.8 MB
#   arp, hostname, ifconfig, netstat, route, plipconfig, iptunnel
# jq              1.1 MB
#   jq is like sed for JSON data, you can use it to slice and filter and map
# sudo            1.3 MB
#   sudo binary
# psmisc          1.445 MB
#   fuser – identifies what processes are using files.
#   killall – kills a process by its name, similar to a pkill Unices.
#   pstree – Shows currently running processes in a tree format.
#   peekfd – Peek at file descriptors of running processes.
# iproute2        2.971 MB
#   to use `ip` command
# iputils-ping    3.7 MB
#   ping, ping6 - send ICMP ECHO_REQUEST to network hosts
# dbus-x11        4.6 MB
#   is needed to avoid http://askubuntu.com/q/237893/134645
# wget            7.3 MB
#   The non-interactive network downloader
# curl             17 MB (real +diff when with wget: 7 MB)
#   transfer URL data using various Internet protocols
# ---------------------------------------------------------
# If we install them separately the total SUM() gives 39 MB
# If we install them together   the total SUM() gives 25 MB
# ---------------------------------------------------------
# Removed packages:
#   telnet          5.2 MB
#     for debugging firewall issues
#   grc              33 MB !!
#     is a terminal colorizer that works nice with tail https://github.com/garabik/grc
#   moreutils        44 MB !!
#     has `ts` that will prepend a timestamp to every line of input you give it
# Layer size: medium: 29.8 MB
# Layer size: medium: 27.9 MB (with --no-install-recommends)
RUN apt -qqy update \
  && apt -qqy install \
    libltdl7 \
    libhavege1 \
    netcat-openbsd \
    pwgen \
    bc \
    unzip \
    bzip2 \
    apt-utils \
    net-tools \
    jq \
    sudo \
    psmisc \
    iproute2 \
    iputils-ping \
    dbus-x11 \
    wget \
    curl \
  && apt -qyy autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

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

#========================================
# Add normal user with passwordless sudo
#========================================
# Layer size: tiny: 0.3 MB
RUN useradd seluser \
         --shell /bin/bash  \
         --create-home \
  && usermod -a -G sudo seluser \
  && gpasswd -a seluser video \
  && echo 'seluser:secret' | chpasswd \
  && useradd extrauser \
         --shell /bin/bash  \
  && usermod -a -G sudo extrauser \
  && gpasswd -a extrauser video \
  && gpasswd -a extrauser seluser \
  && echo 'extrauser:secret' | chpasswd \
  && echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers

#============
# VNC Server
#============
# Layer size: medium: 12.67 MB
# Layer size: medium: 10.08 MB (with --no-install-recommends)
RUN apt -qqy update \
  && apt -qqy install \
    x11vnc \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

#===================================================
# Run the following commands as non-privileged user
#===================================================
USER seluser

########################################
# noVNC to expose VNC via an html page #
########################################
# Download elgalu/noVNC dated 2016-11-18 commit 9223e8f2d1c207fb74cb4b8cc243e59d84f9e2f6
# Download kanaka/noVNC dated 2016-11-10 commit 80b7dde665cac937aa0929d2b75aa482fc0e10ad
# Download kanaka/noVNC dated 2016-02-24 commit b403cb92fb8de82d04f305b4f14fa978003890d7
# Download kanaka/websockify dated 2016-10-10 commit cb1508fa495bea4b333173705772c1997559ae4b
# Download kanaka/websockify dated 2015-06-02 commit 558a6439f14b0d85a31145541745e25c255d576b
# Layer size: small: 2.919 MB
ENV NOVNC_SHA="9223e8f2d1c207fb74cb4b8cc243e59d84f9e2f6" \
    WEBSOCKIFY_SHA="cb1508fa495bea4b333173705772c1997559ae4b"
RUN  wget -nv -O noVNC.zip \
       "https://github.com/elgalu/noVNC/archive/${NOVNC_SHA}.zip" \
  && unzip -x noVNC.zip \
  && mv noVNC-${NOVNC_SHA} noVNC \
  && rm noVNC.zip \
  && wget -nv -O websockify.zip \
      "https://github.com/kanaka/websockify/archive/${WEBSOCKIFY_SHA}.zip" \
  && unzip -x websockify.zip \
  && rm websockify.zip \
  && mv websockify-${WEBSOCKIFY_SHA} ./noVNC/utils/websockify

#=============================
# sudo by default from now on
#=============================
USER root

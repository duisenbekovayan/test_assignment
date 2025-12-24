FROM quay.io/centos/centos:stream8

ARG BUILDER_UID=1000
ARG BUILDER_GID=1000
ARG BUILDER_USER=builder
ARG BUILDER_GROUP=builder

LABEL maintainer="Kernel Build Engineer"
LABEL description="CentOS Stream 8 Kernel Build Environment"
LABEL version="1.0"

RUN set -eux; \
    for f in /etc/yum.repos.d/CentOS-Stream-*.repo; do \
      if [ -f "$f" ]; then \
        sed -i \
          -e 's|^mirrorlist=|#mirrorlist=|g' \
          -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
          "$f"; \
      fi; \
    done

RUN set -eux; \
    dnf -y update && \
    dnf -y install \
      rpm-build rpmdevtools rpm-sign \
      dnf-plugins-core yum-utils \
      make gcc gcc-c++ binutils \
      bison flex bc \
      elfutils-libelf-devel openssl-devel \
      ncurses-devel hmaccalc perl-ExtUtils-Embed \
      pesign xmlto asciidoc hmaccalc \
      git curl ca-certificates wget \
      python3 python3-devel \
      rsync patch diffutils \
    && dnf -y clean all \
    && rm -rf /var/cache/dnf/*

RUN set -eux; \
    groupadd -g ${BUILDER_GID} ${BUILDER_GROUP} || true; \
    useradd -m -u ${BUILDER_UID} -g ${BUILDER_GID} -s /bin/bash ${BUILDER_USER} || true

WORKDIR /home/${BUILDER_USER}

ENV HOME=/home/${BUILDER_USER} \
    RPMBUILD=/home/${BUILDER_USER}/rpmbuild \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN set -eux; \
    mkdir -p /home/${BUILDER_USER}/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} || true; \
    chown -R ${BUILDER_UID}:${BUILDER_GID} /home/${BUILDER_USER} || true

COPY --chown=${BUILDER_UID}:${BUILDER_GID} entrypoint.sh /home/${BUILDER_USER}/entrypoint.sh
RUN chmod 0755 /home/${BUILDER_USER}/entrypoint.sh

USER root

VOLUME ["/out"]

ENTRYPOINT ["/home/builder/entrypoint.sh"]

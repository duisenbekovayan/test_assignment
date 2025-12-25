# CentOS Stream 8 Kernel Build Environment
# Dockerfile for building kernel SRPMs

FROM quay.io/centos/centos:stream8

LABEL maintainer="Kernel Build Engineer"
LABEL description="CentOS Stream 8 Kernel Build Environment"
LABEL version="1.0"

# Fix CentOS Stream 8 repository configuration
# mirrorlist.centos.org no longer works, use vault.centos.org
RUN set -eux; \
    sed -i \
        -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' \
        /etc/yum.repos.d/CentOS-Stream-*.repo

# Enable PowerTools repository (required for kernel build dependencies)
RUN dnf -y install dnf-plugins-core && \
    dnf config-manager --set-enabled powertools

# Install EPEL repository (for additional packages)
RUN dnf -y install epel-release

# Install all required build dependencies
RUN dnf -y update && \
    dnf -y install \
        # RPM build tools
        rpm-build \
        rpmdevtools \
        dnf-plugins-core \
        yum-utils \
        # Compiler and build tools
        gcc \
        gcc-c++ \
        make \
        binutils \
        bison \
        flex \
        bc \
        # LLVM/Clang (required for BPF)
        clang \
        llvm \
        # Kernel build dependencies
        elfutils-libelf-devel \
        elfutils-devel \
        openssl-devel \
        ncurses-devel \
        perl-ExtUtils-Embed \
        perl-generators \
        pesign \
        xmlto \
        asciidoc \
        hmaccalc \
        audit-libs-devel \
        binutils-devel \
        java-devel \
        numactl-devel \
        pciutils-devel \
        python3-devel \
        python3-docutils \
        newt-devel \
        perl-devel \
        # Missing dependencies from error
        bpftool \
        dwarves \
        libcap-devel \
        libmnl-devel \
        libnl3-devel \
        libbabeltrace-devel \
        libbpf-devel \
        libtraceevent-devel \
        xz-devel \
        net-tools \
        kabi-dw \
        # Utilities
        git \
        curl \
        wget \
        rsync \
        patch \
        diffutils \
        cpio \
        xz \
        bzip2 \
        tar \
        findutils \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

# Create build user and mockbuild user (to avoid warnings with CentOS SRPMs)
ARG BUILDER_UID=1000
ARG BUILDER_GID=1000
RUN groupadd -g ${BUILDER_GID} builder 2>/dev/null || true && \
    useradd -m -u ${BUILDER_UID} -g ${BUILDER_GID} -s /bin/bash builder 2>/dev/null || true && \
    groupadd mockbuild 2>/dev/null || true && \
    useradd -g mockbuild mockbuild 2>/dev/null || true

# Setup RPM build directories
RUN mkdir -p /home/builder/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} && \
    chown -R builder:builder /home/builder

# Also setup for root user (dnf builddep requires root)
RUN mkdir -p /root/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /home/builder

# Output volume
VOLUME ["/out"]

# Use root by default (needed for dnf builddep)
USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
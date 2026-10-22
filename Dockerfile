FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV SOFT=/soft

# Shared build prerequisites are installed together before the bioinformatics tools.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        libbz2-dev \
        libcurl4-openssl-dev \
        liblzma-dev \
        libncurses-dev \
        libperl-dev \
        libssl-dev \
        pkg-config \
        perl \
        python3 \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p "${SOFT}" /tmp/build

WORKDIR /work
CMD ["bash"]

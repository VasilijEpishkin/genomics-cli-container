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
        python3-dev \
        python3-setuptools \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p "${SOFT}" /tmp/build

# libdeflate 1.26 — official release dated 2026-08-22.
ENV LIBDEFLATE=${SOFT}/libdeflate_1.26
RUN set -eux; \
    mkdir -p /tmp/build/libdeflate; \
    curl -fsSL https://github.com/ebiggers/libdeflate/archive/refs/tags/v1.26.tar.gz \
      | tar -xz --strip-components=1 -C /tmp/build/libdeflate; \
    cmake -S /tmp/build/libdeflate -B /tmp/build/libdeflate-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="${LIBDEFLATE}" \
      -DCMAKE_INSTALL_LIBDIR=lib; \
    cmake --build /tmp/build/libdeflate-build --parallel "$(nproc)"; \
    cmake --install /tmp/build/libdeflate-build; \
    rm -rf /tmp/build/libdeflate /tmp/build/libdeflate-build

# HTSlib 1.24 — official release dated 2026-07-09.
ENV HTSLIB=${SOFT}/htslib_1.24
RUN set -eux; \
    mkdir -p /tmp/build/htslib; \
    curl -fsSL https://github.com/samtools/htslib/releases/download/1.24/htslib-1.24.tar.bz2 \
      | tar -xj --strip-components=1 -C /tmp/build/htslib; \
    cd /tmp/build/htslib; \
    CPPFLAGS="-I${LIBDEFLATE}/include" \
    LDFLAGS="-L${LIBDEFLATE}/lib -Wl,-rpath,${LIBDEFLATE}/lib" \
      ./configure --prefix="${HTSLIB}" --libdir="${HTSLIB}/lib" --with-libdeflate; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/build/htslib

# SAMtools 1.24 — official release dated 2026-07-09.
ENV SAMTOOLS=${SOFT}/samtools_1.24/bin/samtools
RUN set -eux; \
    mkdir -p /tmp/build/samtools; \
    curl -fsSL https://github.com/samtools/samtools/releases/download/1.24/samtools-1.24.tar.bz2 \
      | tar -xj --strip-components=1 -C /tmp/build/samtools; \
    cd /tmp/build/samtools; \
    CPPFLAGS="-I${HTSLIB}/include" \
    LDFLAGS="-L${HTSLIB}/lib -Wl,-rpath,${HTSLIB}/lib -Wl,-rpath,${LIBDEFLATE}/lib" \
      ./configure --prefix="${SOFT}/samtools_1.24" --with-htslib="${HTSLIB}"; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/build/samtools

# BCFtools 1.24 — official release dated 2026-07-09.
ENV BCFTOOLS=${SOFT}/bcftools_1.24/bin/bcftools
RUN set -eux; \
    mkdir -p /tmp/build/bcftools; \
    curl -fsSL https://github.com/samtools/bcftools/releases/download/1.24/bcftools-1.24.tar.bz2 \
      | tar -xj --strip-components=1 -C /tmp/build/bcftools; \
    cd /tmp/build/bcftools; \
    CPPFLAGS="-I${HTSLIB}/include" \
    LDFLAGS="-L${HTSLIB}/lib -Wl,-rpath,${HTSLIB}/lib -Wl,-rpath,${LIBDEFLATE}/lib" \
      ./configure --prefix="${SOFT}/bcftools_1.24" --with-htslib="${HTSLIB}"; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/build/bcftools

# VCFtools 0.1.17 — official release dated 2025-05-15.
ENV VCFTOOLS=${SOFT}/vcftools_0.1.17/bin/vcftools
RUN set -eux; \
    mkdir -p /tmp/build/vcftools; \
    curl -fsSL https://github.com/vcftools/vcftools/releases/download/v0.1.17/vcftools-0.1.17.tar.gz \
      | tar -xz --strip-components=1 -C /tmp/build/vcftools; \
    cd /tmp/build/vcftools; \
    ./configure --prefix="${SOFT}/vcftools_0.1.17"; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/build/vcftools

ENV PATH="${SOFT}/libdeflate_1.26/bin:${SOFT}/htslib_1.24/bin:${SOFT}/samtools_1.24/bin:${SOFT}/bcftools_1.24/bin:${SOFT}/vcftools_0.1.17/bin:${PATH}"
ENV LD_LIBRARY_PATH="${SOFT}/libdeflate_1.26/lib:${SOFT}/htslib_1.24/lib:${LD_LIBRARY_PATH}"
ENV PKG_CONFIG_PATH="${SOFT}/htslib_1.24/lib/pkgconfig:${SOFT}/libdeflate_1.26/lib/pkgconfig:${PKG_CONFIG_PATH}"

# pysam 0.24.1 — official source release dated 2026-09-07.
ENV PYSAM=${SOFT}/pysam_0.24.1
RUN set -eux; \
    mkdir -p /tmp/build/pysam; \
    curl -fsSL https://files.pythonhosted.org/packages/01/d0/e9271669f97ce454d1aa97f9ce0d3e84376295f352ad6c5d2c3998e38f66/pysam-0.24.1.tar.gz \
      -o /tmp/build/pysam-0.24.1.tar.gz; \
    echo '90f612afccdb454d2447ecb5229266c6e7f991093deed4ed0a791db01f7fc994  /tmp/build/pysam-0.24.1.tar.gz' | sha256sum -c -; \
    tar -xzf /tmp/build/pysam-0.24.1.tar.gz --strip-components=1 -C /tmp/build/pysam; \
    cd /tmp/build/pysam; \
    cd htslib; \
    ./configure --disable-ref-cache --enable-libcurl; \
    make -j"$(nproc)" CFLAGS='-O2 -fPIC' lib-static; \
    cd ..; \
    python3 setup.py build; \
    python3 setup.py install --prefix="${PYSAM}" --single-version-externally-managed --record=/tmp/pysam-install-record.txt; \
    rm -f /tmp/pysam-install-record.txt; \
    rm -rf /tmp/build/pysam /tmp/build/pysam-0.24.1.tar.gz
ENV PYTHONPATH="${PYSAM}/lib/python3.10/site-packages:${PYTHONPATH}"

COPY task3/convert_alleles_to_ref_alt.py /usr/local/bin/convert_alleles_to_ref_alt.py
COPY task3/prepare_reference.sh /usr/local/bin/prepare_reference.sh
RUN chmod 0755 /usr/local/bin/convert_alleles_to_ref_alt.py /usr/local/bin/prepare_reference.sh

WORKDIR /work
CMD ["bash"]

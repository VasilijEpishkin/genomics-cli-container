# Genomics CLI container

Container based on the official Ubuntu 22.04 image. Shared build dependencies are installed before the bioinformatics toolchain.

## Build

```bash
docker build --pull -t seqtools:1.0 .
```

## Run interactively

```bash
docker run --rm -it seqtools:1.0
```

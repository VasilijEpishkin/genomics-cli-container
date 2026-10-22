# Genomics CLI container

The image uses Ubuntu 22.04 and builds libdeflate 1.26, HTSlib 1.24 and SAMtools 1.24 from their official upstream releases. Each component is installed under its own versioned directory in `/soft`.

## Build and interactive use

```bash
docker build --pull -t seqtools:1.0 .
docker run --rm -it seqtools:1.0
```

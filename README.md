# Bioinformatics tools image

Контейнер для работы с форматами SAM/BAM/CRAM и VCF/BCF. База — официальный `ubuntu:22.04`. Специализированные программы собираются из официальных исходников и устанавливаются в отдельные каталоги `/soft`.

## Состав

| Программа | Версия | Каталог |
|---|---:|---|
| libdeflate | 1.26 | `/soft/libdeflate_1.26` |
| HTSlib | 1.24 | `/soft/htslib_1.24` |
| SAMtools | 1.24 | `/soft/samtools_1.24` |
| BCFtools | 1.24 | `/soft/bcftools_1.24` |
| VCFtools | 0.1.17 | `/soft/vcftools_0.1.17` |

Версии выбраны по последним официальным релизам на 22.10.2026. Сборка выполняется с параллелизмом по `nproc`. Загрузки и временные исходники удаляются в том же слое, в котором собирается соответствующий инструмент; кэш apt удаляется после установки общих зависимостей.

## Сборка образа

Выполнить из каталога, где находится Dockerfile:

```bash
docker build --pull -t seqtools:1.0 .
```

## Интерактивный запуск

```bash
docker run --rm -it seqtools:1.0
```

Чтобы работать с файлами хоста, подключить каталог данных:

```bash
docker run --rm -it -v "$PWD/data:/data" -w /data seqtools:1.0
```

## Проверка установленного ПО

В контейнере:

```bash
samtools --help
"$SAMTOOLS" --version
htsfile --version
bgzip --version
"$BCFTOOLS" --version
"$VCFTOOLS" --help
"$VCFTOOLS" --version
pkg-config --modversion libdeflate
```

Переменные `SAMTOOLS`, `BCFTOOLS` и `VCFTOOLS` содержат полные пути к исполняемым файлам. Каталоги `bin` всех программ добавлены в `PATH`; библиотеки libdeflate и HTSlib добавлены в `LD_LIBRARY_PATH`.

## Официальные источники релизов

- [libdeflate 1.26](https://github.com/ebiggers/libdeflate/releases/tag/v1.26) — 22.08.2026
- [HTSlib 1.24](https://github.com/samtools/htslib/releases/tag/1.24) — 09.07.2026
- [SAMtools 1.24](https://github.com/samtools/samtools/releases/tag/1.24) — 09.07.2026
- [BCFtools 1.24](https://github.com/samtools/bcftools/releases/tag/1.24) — 09.07.2026
- [VCFtools 0.1.17](https://github.com/vcftools/vcftools/releases/tag/v0.1.17) — 15.05.2025

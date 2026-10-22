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
| pysam | 0.24.1 | `/soft/pysam_0.24.1` (сборка из исходников) |

Основные инструменты и встроенная в pysam HTSlib компилируются с параллелизмом по `nproc`. Загрузки и временные исходники удаляются в том же слое, в котором собирается соответствующий инструмент; кэш apt удаляется после установки общих зависимостей.

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
- [pysam 0.24.1 — исходный архив](https://pypi.org/project/pysam/0.24.1/#files) — 07.09.2026; SHA-256 закреплён в Dockerfile

## Решение задачи 3: GRAF FP SNPs → REF/ALT

В контейнер добавлены Python 3 и `pysam 0.24.1`. Скрипт `task3/convert_alleles_to_ref_alt.py` сверяет каждый однонуклеотидный аллель с референсом через `pysam.Fastafile`. Исходный GRAF-файл содержит столбцы `rs#`, `chromosome`, `GB37_position`, `GB38_position`, `allele1`, `allele2`; этот заголовок используется при подготовке.

Подготовка 10 000 аутосомных вариантов и исключение 1 000 записей chr23:

```bash
bash task3/prepare_fp_snps.sh \
  data/FP_SNPs.txt \
  data/FP_SNPs_10k_GB38_twoAllelsFormat.tsv
```

В каталог референса должны быть заранее подготовлены раздельные FASTA и индексы `chr1.fa` … `chr22.fa`, `chrM.fa`, `chrX.fa`, `chrY.fa` и соответствующие `.fai`. Референс в репозиторий не включён. Пример запуска с монтированием входных и референсных файлов:

```bash
docker run --rm \
  -v "$PWD/data:/work/data" \
  -v "/mnt/data/ref/GRCh38.d1.vd1_mainChr/sepChrs:/ref/GRCh38.d1.vd1_mainChr/sepChrs:ro" \
  seqtools:1.0 \
  convert_alleles_to_ref_alt.py \
    --input /work/data/FP_SNPs_10k_GB38_twoAllelsFormat.tsv \
    --output /work/data/FP_SNPs_10k_GB38_ref_alt.tsv \
    --log-file /work/data/convert_alleles.log
```

Координата `POS` во входе 1-based, поэтому для `fetch` используется интервал `[POS - 1, POS)`. После прямой проверки скрипт учитывает комплементарные пары A↔T и C↔G, которые требуются для строк с аллелями на противоположной цепи. Необъяснимые несовпадения попадают в лог; частичный результат удаляется, программа завершает работу с ошибкой. Полная инструкция, скрипт подготовки и результаты находятся в [FP_SNPs_README.md](FP_SNPs_README.md).


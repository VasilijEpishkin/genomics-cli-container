# Задача 3: разрешение аллелей GRAF в REF/ALT

## Исходные данные и формат

В `data/FP_SNPs.txt` помещён файл из [официального архива GRAF 2.4](https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/GetZip.cgi?zip_name=GRAF_files.zip), на который ведёт [страница NCBI dbGaP Software](https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/Software.cgi). Заголовок файла: `rs#`, `chromosome`, `GB37_position`, `GB38_position`, `allele1`, `allele2`. В файле 11 000 записей данных: 10 000 аутосомных и 1 000 на хромосоме `23` (X). SHA-256 сохранённой копии: `f1d9162a7fe2d97513b4f915e616fdd0f04e6fbd023e57d0a81559f63e019cf5`.


## Подготовка входа

Из шестиколоночного источника выбираются `chromosome`, `GB38_position`, `rs#`, `allele1` и `allele2`. Координата `GB37_position` исключается, хромосомы нормализуются к `chr1`–`chr22`, идентификаторы — к `rs...`, записи chr23 удаляются.

```bash
bash task3/prepare_fp_snps.sh \
  data/FP_SNPs.txt \
  data/FP_SNPs_10k_GB38_twoAllelsFormat.tsv
```

Скрипт проверяет точный исходный заголовок и ожидаемые количества строк перед записью результата.

## Подготовка референса

Скачайте официальный архив GRCh38.d1.vd1 и проверьте опубликованную GDC контрольную сумму MD5 `3ffbcfe2d05d43206f57f81ebb251dc9`. Референс не входит в репозиторий.

```bash
curl -L 'https://api.gdc.cancer.gov/data/254f697d-310d-4d7d-a27b-27fbf767a834' \
  -o /mnt/data/ref/GRCh38.d1.vd1.fa.tar.gz
docker run --rm \
  -v /mnt/data/ref:/refdata \
  seqtools:1.0 \
  prepare_reference.sh \
    /refdata/GRCh38.d1.vd1.fa.tar.gz \
    /refdata/GRCh38.d1.vd1_mainChr/sepChrs
```

`prepare_reference.sh` проверяет MD5, извлекает основной GDC FASTA, формирует 25 файлов `chr1.fa`–`chr22.fa`, `chrM.fa`, `chrX.fa`, `chrY.fa` и индексирует каждый `.fai`.

## Запуск конвертера

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

Входной POS — 1-based; запрос к `pysam.Fastafile.fetch` использует `[POS - 1, POS)`. Если референс совпал с `allele1`, он записывается в REF, а `allele2` — в ALT; если совпал с `allele2`, порядок аллелей меняется. Если прямого совпадения нет, проверяется комплементарная пара (A↔T, C↔G). Такие строки переводятся на strand референса и отмечаются в логе. Если не совпали ни исходная, ни комплементарная пара либо строка повреждена, ошибка попадает в timestamp-лог, временный результат удаляется, а процесс завершается с ненулевым кодом. Так в итоговый файл не попадают выдуманные REF/ALT.

## Артефакты

- `task3/convert_alleles_to_ref_alt.py` — CLI-конвертер с `--help`, валидацией заголовка и данных, timestamp-логом и атомарной записью результата.
- `task3/prepare_fp_snps.sh` — проверяемая Bash-предобработка источника GRAF.
- `task3/prepare_reference.sh` — проверка GDC MD5, извлечение и индексация отдельных хромосом.
- `data/FP_SNPs.txt` — исходные 11 000 SNP из GRAF 2.4.
- `data/FP_SNPs_10k_GB38_twoAllelsFormat.tsv` — подготовленные 10 000 аутосомных SNP.
- `data/FP_SNPs_10k_GB38_ref_alt.tsv` — результат `REF/ALT` после проверки на референсе.
- `data/convert_alleles.log` — журнал выполненного запуска.

Источник референса: [GDC Reference Files](https://gdc.cancer.gov/about-data/gdc-data-processing/gdc-reference-files).

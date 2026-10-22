#!/usr/bin/env bash
set -euo pipefail

input=${1:-data/FP_SNPs.txt}
output=${2:-data/FP_SNPs_10k_GB38_twoAllelsFormat.tsv}

if [[ ! -f "$input" ]]; then
  printf 'Input file not found: %s\n' "$input" >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
tmp=$(mktemp "${output}.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT

awk -F '\t' -v OFS='\t' '
  NR == 1 {
    sub(/\r$/, "")
    if ($0 != "rs#\tchromosome\tGB37_position\tGB38_position\tallele1\tallele2") {
      print "Unexpected GRAF FP_SNPs.txt header" > "/dev/stderr"
      bad = 1
      exit 2
    }
    print "#CHROM", "POS", "ID", "allele1", "allele2"
    next
  }
  {
    sub(/\r$/, "")
    if (NF != 6) {
      printf "Line %d: expected 6 columns, found %d\n", NR, NF > "/dev/stderr"
      bad = 1
      exit 2
    }
    if ($2 == "23") {
      x_count++
      next
    }
    if ($2 !~ /^([1-9]|1[0-9]|2[0-2])$/ || $4 !~ /^[0-9]+$/ || $4 < 1 || $1 !~ /^[0-9]+$/ || $5 !~ /^[ACGTacgt]$/ || $6 !~ /^[ACGTacgt]$/) {
      printf "Line %d: invalid chromosome, GRCh38 position, ID, or allele\n", NR > "/dev/stderr"
      bad = 1
      exit 2
    }
    id = $1
    if (id !~ /^rs/) id = "rs" id
    print "chr" $2, $4, id, toupper($5), toupper($6)
    autosomal_count++
  }
  END {
    if (bad) exit 2
    if (autosomal_count != 10000 || x_count != 1000) {
      printf "Expected 10000 autosomal rows and 1000 chr23 rows; found %d and %d\n", autosomal_count, x_count > "/dev/stderr"
      exit 2
    }
    printf "Prepared %d autosomal SNPs; excluded %d chr23 SNPs\n", autosomal_count, x_count > "/dev/stderr"
  }
' "$input" > "$tmp"

mv "$tmp" "$output"
trap - EXIT

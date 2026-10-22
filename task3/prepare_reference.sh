#!/usr/bin/env bash
set -euo pipefail

archive=${1:?Usage: prepare_reference.sh GRCh38.d1.vd1.fa.tar.gz OUTPUT_DIRECTORY}
output_dir=${2:?Usage: prepare_reference.sh GRCh38.d1.vd1.fa.tar.gz OUTPUT_DIRECTORY}
expected_md5=3ffbcfe2d05d43206f57f81ebb251dc9

if [[ ! -f "$archive" ]]; then
  printf 'Reference archive not found: %s\n' "$archive" >&2
  exit 1
fi
actual_md5=$(md5sum "$archive" | cut -d ' ' -f 1)
if [[ "$actual_md5" != "$expected_md5" ]]; then
  printf 'Reference archive MD5 mismatch: expected %s, found %s\n' "$expected_md5" "$actual_md5" >&2
  exit 1
fi

mkdir -p "$output_dir"
temp_dir=$(mktemp -d)
stage_dir=$(mktemp -d "$output_dir/.prepare.XXXXXX")
trap 'rm -rf "$temp_dir" "$stage_dir"' EXIT
tar -xzf "$archive" -C "$temp_dir" GRCh38.d1.vd1.fa
reference="$temp_dir/GRCh38.d1.vd1.fa"
samtools faidx "$reference"

for chromosome in {1..22} M X Y; do
  name="chr${chromosome}"
  samtools faidx "$reference" "$name" > "$stage_dir/${name}.fa"
  samtools faidx "$stage_dir/${name}.fa"
done

for file in "$stage_dir"/*; do
  mv -f "$file" "$output_dir/"
done
printf 'Prepared 25 indexed chromosome FASTA files in %s\n' "$output_dir"

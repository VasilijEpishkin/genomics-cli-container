#!/usr/bin/env python3
"""Resolve GRAF allele pairs against chromosome FASTA files."""

from __future__ import annotations

import argparse
import logging
import os
import re
import sys
import tempfile
from contextlib import ExitStack
from pathlib import Path

import pysam


INPUT_HEADER = ("#CHROM", "POS", "ID", "allele1", "allele2")
OUTPUT_HEADER = ("#CHROM", "POS", "ID", "REF", "ALT")
CHROM_PATTERN = re.compile(r"chr(?:[1-9]|1[0-9]|2[0-2]|M|X|Y)\Z")
BASE_PATTERN = re.compile(r"[ACGT]\Z")
COMPLEMENT = {"A": "T", "T": "A", "C": "G", "G": "C"}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert GRAF allele1/allele2 pairs to REF/ALT using pysam and a GRCh38 FASTA directory."
    )
    parser.add_argument("-i", "--input", required=True, type=Path, help="Input TSV with #CHROM, POS, ID, allele1, allele2")
    parser.add_argument("-o", "--output", required=True, type=Path, help="Output TSV with #CHROM, POS, ID, REF, ALT")
    parser.add_argument(
        "-r", "--ref-dir", type=Path,
        default=Path("/ref/GRCh38.d1.vd1_mainChr/sepChrs"),
        help="Directory containing chr1.fa through chr22.fa (and chrM/X/Y.fa if needed)",
    )
    parser.add_argument("-l", "--log-file", type=Path, help="Timestamped log file (default: OUTPUT.log)")
    return parser.parse_args()


def configure_logging(log_path: Path) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S%z",
        handlers=[logging.StreamHandler(), logging.FileHandler(log_path, mode="w", encoding="utf-8")],
        force=True,
    )


def paths_refer_to_same_file(first: Path, second: Path) -> bool:
    try:
        if os.path.samefile(first, second):
            return True
    except OSError:
        pass
    return first.resolve(strict=False) == second.resolve(strict=False)


def validate_paths(input_path: Path, output_path: Path, log_path: Path) -> None:
    paths = (("input", input_path), ("output", output_path), ("log", log_path))
    for index, (first_name, first_path) in enumerate(paths):
        for second_name, second_path in paths[index + 1 :]:
            if paths_refer_to_same_file(first_path, second_path):
                raise ValueError(
                    f"{first_name} and {second_name} paths must refer to different files: "
                    f"{first_path} and {second_path}"
                )


def resolve_contig(fasta: pysam.Fastafile, chrom: str) -> str:
    candidates = (chrom, chrom[3:])
    for candidate in candidates:
        if candidate in fasta.references:
            return candidate
    raise ValueError(f"{chrom}: FASTA has no contig named {chrom!r} or {chrom[3:]!r}")


def convert(input_path: Path, output_path: Path, ref_dir: Path) -> tuple[int, int, int]:
    if not input_path.is_file():
        raise ValueError(f"Input file does not exist: {input_path}")
    if not ref_dir.is_dir():
        raise ValueError(f"Reference directory does not exist: {ref_dir}")
    if input_path.resolve() == output_path.resolve():
        raise ValueError("Input and output paths must be different")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path: Path | None = None
    fasta_by_chrom: dict[str, pysam.Fastafile] = {}
    processed = 0
    issues = 0
    strand_flipped = 0
    contig_by_chrom: dict[str, str] = {}

    try:
        with ExitStack() as stack:
            input_file = stack.enter_context(input_path.open("r", encoding="utf-8", newline=""))
            first_line = input_file.readline()
            header = tuple(first_line.rstrip("\r\n").split("\t"))
            if header != INPUT_HEADER:
                raise ValueError(f"Invalid header: expected {INPUT_HEADER!r}, got {header!r}")

            output_file = tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", newline="", dir=output_path.parent,
                prefix=f".{output_path.name}.", suffix=".tmp", delete=False,
            )
            temp_path = Path(output_file.name)
            stack.enter_context(output_file)
            output_file.write("\t".join(OUTPUT_HEADER) + "\n")

            for line_number, line in enumerate(input_file, start=2):
                row = line.rstrip("\r\n")
                if not row:
                    continue
                fields = row.split("\t")
                if len(fields) != 5:
                    logging.error("line %d: expected 5 fields, found %d", line_number, len(fields))
                    issues += 1
                    continue

                chrom, pos_text, variant_id, allele1, allele2 = fields
                if not CHROM_PATTERN.fullmatch(chrom):
                    logging.error("line %d: unsupported chromosome %r", line_number, chrom)
                    issues += 1
                    continue
                if not pos_text.isdecimal() or int(pos_text) < 1:
                    logging.error("line %d: POS must be a positive 1-based integer, got %r", line_number, pos_text)
                    issues += 1
                    continue
                allele1, allele2 = allele1.upper(), allele2.upper()
                if not BASE_PATTERN.fullmatch(allele1) or not BASE_PATTERN.fullmatch(allele2) or allele1 == allele2:
                    logging.error("line %d: allele1 and allele2 must be distinct single bases A/C/G/T", line_number)
                    issues += 1
                    continue

                fasta = fasta_by_chrom.get(chrom)
                if fasta is None:
                    fasta_path = ref_dir / f"{chrom}.fa"
                    if not fasta_path.is_file() or not Path(f"{fasta_path}.fai").is_file():
                        logging.error("line %d: FASTA or index is missing for %s (%s)", line_number, chrom, fasta_path)
                        issues += 1
                        continue
                    candidate = None
                    try:
                        candidate = pysam.Fastafile(str(fasta_path))
                        contig = resolve_contig(candidate, chrom)
                    except (OSError, ValueError) as exc:
                        if candidate is not None:
                            candidate.close()
                        logging.error("line %d: cannot open reference for %s: %s", line_number, chrom, exc)
                        issues += 1
                        continue
                    fasta = candidate
                    fasta_by_chrom[chrom] = fasta
                    contig_by_chrom[chrom] = contig
                    stack.callback(fasta.close)
                else:
                    contig = contig_by_chrom[chrom]

                pos = int(pos_text)
                try:
                    ref_base = fasta.fetch(contig, pos - 1, pos).upper()
                except (OSError, ValueError) as exc:
                    logging.error("line %d: reference lookup failed at %s:%s: %s", line_number, chrom, pos, exc)
                    issues += 1
                    continue
                if len(ref_base) != 1:
                    logging.error("line %d: position is outside the reference at %s:%s", line_number, chrom, pos)
                    issues += 1
                    continue

                if ref_base == allele1:
                    ref, alt = allele1, allele2
                elif ref_base == allele2:
                    ref, alt = allele2, allele1
                else:
                    comp1, comp2 = COMPLEMENT[allele1], COMPLEMENT[allele2]
                    if ref_base == comp1:
                        ref, alt = comp1, comp2
                        strand_flipped += 1
                        logging.warning("line %d: complemented allele pair to reference strand at %s:%s", line_number, chrom, pos)
                    elif ref_base == comp2:
                        ref, alt = comp2, comp1
                        strand_flipped += 1
                        logging.warning("line %d: complemented allele pair to reference strand at %s:%s", line_number, chrom, pos)
                    else:
                        logging.error(
                            "line %d: reference base %s matches neither allele nor its complement (%s/%s) at %s:%s",
                            line_number, ref_base, allele1, allele2, chrom, pos,
                        )
                        issues += 1
                        continue

                output_file.write("\t".join((chrom, pos_text, variant_id, ref, alt)) + "\n")
                processed += 1

            output_file.flush()
            os.fsync(output_file.fileno())

        if issues:
            raise ValueError(f"Conversion stopped: {issues} invalid or unresolved row(s); partial output discarded")
        if processed == 0:
            raise ValueError("Input contains no data rows")

        os.chmod(temp_path, 0o644)
        os.replace(temp_path, output_path)
        temp_path = None
        return processed, strand_flipped, issues
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def main() -> int:
    args = arguments()
    log_path = args.log_file or args.output.with_suffix(args.output.suffix + ".log")
    try:
        validate_paths(args.input, args.output, log_path)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    try:
        configure_logging(log_path)
    except OSError as exc:
        print(f"ERROR: cannot open log file {log_path}: {exc}", file=sys.stderr)
        return 1
    logging.info("Starting conversion: input=%s output=%s ref_dir=%s", args.input, args.output, args.ref_dir)
    try:
        processed, strand_flipped, issues = convert(args.input, args.output, args.ref_dir)
    except (OSError, ValueError, pysam.SamtoolsError) as exc:
        logging.error("Conversion failed: %s", exc)
        return 1
    logging.info("Completed: %d variants written; %d strand-complemented; %d issues", processed, strand_flipped, issues)
    return 0


if __name__ == "__main__":
    sys.exit(main())

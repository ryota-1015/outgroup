#!/usr/bin/env python3
"""Build data/trios.tsv from the evo-subster directory listings.

Inputs:
  data/tmp/ls_results_summary_all.txt  (ls -R of <evo-subster>/results/summary/all/)
  data/tmp/ls_result.txt               (ls -R of <evo-subster>/results/, used for clade lookup)

Output:
  data/trios.tsv  with columns:
    trio_name  clade  role  code  accession  notes

Accessions come from the filenames inside each trio's metadata/ subdir,
e.g. `Denhet1_GCA_910591775.1.json` -> code=Denhet1, accession=GCA_910591775.1.
"""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SUMMARY_LS = REPO_ROOT / "data" / "tmp" / "ls_results_summary_all.txt"
FULL_LS = REPO_ROOT / "data" / "tmp" / "ls_result.txt"
OUT_TSV = REPO_ROOT / "data" / "trios.tsv"

CLADES = (
    "actinopteri apicomplexa arthropoda chordata cnidaria fungi mollusca "
    "oomycota phaeophyceae porifera"
).split()

TRIO_HEADER_RE = re.compile(r"^\./([A-Z][a-z]+\d_[A-Z][a-z]+\d_[A-Z][a-z]+\d):$")
DATE_HEADER_RE = re.compile(r"^\./([A-Z][a-z]+\d_[A-Z][a-z]+\d_[A-Z][a-z]+\d)/(\d{8}):$")
METADATA_HEADER_RE = re.compile(
    r"^\./([A-Z][a-z]+\d_[A-Z][a-z]+\d_[A-Z][a-z]+\d)/(\d{8})/metadata:$"
)
ACC_FILE_RE = re.compile(r"^([A-Z][a-z]+\d)_(GC[AF]_\d+\.\d+)\.json$")
CLADE_HEADER_RE = re.compile(
    rf"^\./(?P<clade>{'|'.join(CLADES)})/(?P<trio>[A-Z][a-z]+\d_[A-Z][a-z]+\d_[A-Z][a-z]+\d):$"
)

AMF_EXPECTED = {
    ("Denhet1_Gigros2_Gigmar3", "A", "Denhet1"): "GCA_910591775.1",
    ("Denhet1_Gigros2_Gigmar3", "B", "Gigros2"): "GCA_003550325.1",
    ("Denhet1_Gigros2_Gigmar3", "C", "Gigmar3"): "GCA_009809945.1",
}


def parse_summary(path: Path):
    """Return {trio: {date: [(code, accession), ...]}} from summary/all listing."""
    trios: dict[str, dict[str, list[tuple[str, str]]]] = defaultdict(
        lambda: defaultdict(list)
    )
    current_trio: str | None = None
    current_date: str | None = None
    in_metadata = False
    for line in path.read_text().splitlines():
        if not line:
            in_metadata = False
            continue
        if line.endswith(":"):
            in_metadata = False
            m = METADATA_HEADER_RE.match(line)
            if m:
                current_trio = m.group(1)
                current_date = m.group(2)
                in_metadata = True
                continue
            m = DATE_HEADER_RE.match(line)
            if m:
                current_trio = m.group(1)
                current_date = m.group(2)
                continue
            m = TRIO_HEADER_RE.match(line)
            if m:
                current_trio = m.group(1)
                current_date = None
                continue
            current_trio = None
            current_date = None
            continue
        if in_metadata and current_trio and current_date:
            m = ACC_FILE_RE.match(line.strip())
            if m:
                trios[current_trio][current_date].append((m.group(1), m.group(2)))
    return trios


def parse_clades(path: Path) -> dict[str, str]:
    """Return {trio_name: clade} from the full listing."""
    mapping: dict[str, str] = {}
    for line in path.read_text().splitlines():
        m = CLADE_HEADER_RE.match(line)
        if m:
            mapping[m.group("trio")] = m.group("clade")
    return mapping


def main() -> int:
    if not SUMMARY_LS.exists():
        sys.exit(f"missing {SUMMARY_LS}")
    if not FULL_LS.exists():
        sys.exit(f"missing {FULL_LS}")

    trios = parse_summary(SUMMARY_LS)
    clades = parse_clades(FULL_LS)

    rows: list[tuple[str, str, str, str, str, str]] = []
    species_to_trios: dict[str, list[str]] = defaultdict(list)
    for trio_name in sorted(trios):
        codes = trio_name.split("_")
        assert len(codes) == 3, trio_name
        for code in codes:
            species_to_trios[code].append(trio_name)

    skipped: list[str] = []
    anomalies: list[str] = []
    for trio_name in sorted(trios):
        by_date = trios[trio_name]
        if not by_date:
            skipped.append(f"{trio_name}: no metadata dir")
            continue
        latest_date = max(by_date)
        entries = dict(by_date[latest_date])
        codes = trio_name.split("_")
        clade = clades.get(trio_name, "unclassified")
        if len(entries) != 3:
            anomalies.append(
                f"{trio_name} ({latest_date}): "
                f"expected 3 code->acc entries, got {len(entries)}: {entries}"
            )
        for role, code in zip("ABC", codes):
            accession = entries.get(code, "")
            notes: list[str] = []
            if not accession:
                notes.append("missing_metadata")
            if len(species_to_trios[code]) > 1:
                notes.append("dup_species_across_trios")
            rows.append(
                (
                    trio_name,
                    clade,
                    role,
                    code,
                    accession,
                    ";".join(notes),
                )
            )

    # AMF regression check before writing
    for (trio, role, code), expected in AMF_EXPECTED.items():
        match = [r for r in rows if r[0] == trio and r[2] == role and r[3] == code]
        assert match, f"AMF row missing: {trio}/{role}/{code}"
        actual = match[0][4]
        assert actual == expected, (
            f"AMF regression: {trio}/{role}/{code} -> {actual!r} (expected {expected!r})"
        )

    OUT_TSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_TSV.open("w") as fh:
        fh.write("trio_name\tclade\trole\tcode\taccession\tnotes\n")
        for row in rows:
            fh.write("\t".join(row) + "\n")

    trio_count = len({r[0] for r in rows})
    role_count = len(rows)
    print(f"wrote {OUT_TSV.relative_to(REPO_ROOT)}: {trio_count} trios, {role_count} rows")
    if skipped:
        print(f"skipped {len(skipped)} trios:", file=sys.stderr)
        for s in skipped:
            print(f"  - {s}", file=sys.stderr)
    if anomalies:
        print(f"{len(anomalies)} metadata anomalies:", file=sys.stderr)
        for a in anomalies:
            print(f"  - {a}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Builds MeridianCore's bundled runways.json from the OurAirports airports.csv and runways.csv.

Usage: Scripts/build-runways.py <airports.csv> <runways.csv> [output.json]

Source: https://ourairports.com/data/ (public domain). For every bundled airport (see build-airports.py) keeps up to
four of its longest open runways that have both thresholds surveyed, as [lat, lon, lat, lon] of the two ends.
The take-off uses them so the aircraft rolls down a real runway.
"""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "Packages/MeridianCore/Sources/MeridianCore/Resources"
TYPES = {"large_airport": 0, "medium_airport": 1, "small_airport": 2}


def main() -> None:
    airports_csv, runways_csv = Path(sys.argv[1]), Path(sys.argv[2])
    out = Path(sys.argv[3]) if len(sys.argv) > 3 else RES / "runways.json"
    bundled = {a["iata"] for a in json.loads((RES / "airports.json").read_text())}
    ident = {}
    with airports_csv.open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            iata = r["iata_code"].strip().upper()
            if iata not in bundled or r["scheduled_service"] != "yes" or r["type"] not in TYPES:
                continue
            rank = TYPES[r["type"]]
            if iata in ident and ident[iata][0] <= rank:
                continue
            ident[iata] = (rank, r["ident"])
    by_ident = {v[1]: k for k, v in ident.items()}
    found = {}
    with runways_csv.open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            iata = by_ident.get(r["airport_ident"])
            if iata is None or r["closed"] == "1":
                continue
            try:
                ends = [float(r[k]) for k in ("le_latitude_deg", "le_longitude_deg", "he_latitude_deg", "he_longitude_deg")]
                length = float(r["length_ft"] or 0)
            except ValueError:
                continue
            if length < 2000:
                continue
            found.setdefault(iata, []).append((length, [round(v, 5) for v in ends]))
    data = {k: [e for _, e in sorted(v, key=lambda x: -x[0])[:4]] for k, v in sorted(found.items())}
    out.write_text(json.dumps(data, separators=(",", ":")))
    print(f"{len(data)} of {len(bundled)} airports, {sum(len(v) for v in data.values())} runways -> {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()

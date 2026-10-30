#!/usr/bin/env python3
"""Builds MeridianCore's bundled airports.json from the OurAirports airports.csv.

Usage: Scripts/build-airports.py <airports.csv> [output.json]

Source: https://ourairports.com/data/ (public domain). Keeps airports with an
IATA code and scheduled service. Route data from OpenFlights is not used (ODbL).
"""
import csv
import json
import sys
from pathlib import Path

CONTINENTS = {"AF": "africa", "AN": "antarctica", "AS": "asia", "EU": "europe",
              "NA": "northAmerica", "OC": "oceania", "SA": "southAmerica"}
TYPES = {"large_airport", "medium_airport", "small_airport"}
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "Packages/MeridianCore/Sources/MeridianCore/Resources/airports.json"


def main() -> None:
    src = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUT
    airports = {}
    with src.open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            iata = r["iata_code"].strip().upper()
            if not (len(iata) == 3 and iata.isalpha()):
                continue
            if r["scheduled_service"] != "yes" or r["type"] not in TYPES:
                continue
            # Prefer the bigger airport if a code appears twice.
            rank = {"large_airport": 0, "medium_airport": 1, "small_airport": 2}[r["type"]]
            if iata in airports and airports[iata][0] <= rank:
                continue
            airports[iata] = (rank, {
                "iata": iata,
                "name": r["name"].strip(),
                "city": (r["municipality"] or r["name"]).strip(),
                "countryCode": r["iso_country"].strip(),
                "continent": CONTINENTS[r["continent"]],
                "coordinate": {"latitude": round(float(r["latitude_deg"]), 4),
                               "longitude": round(float(r["longitude_deg"]), 4)},
            })
    data = [airports[k][1] for k in sorted(airports)]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{len(data)} airports -> {out}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Kortex Lead Sanitization and CSV Export Utility
Enterprise protection against CSV Formula Injection (CWE-1236)
and command-line lead processing for internal use only.
"""

import csv
import json
import os
import re
import sys
from datetime import datetime

EMAIL_REGEX = re.compile(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$"
)

FORMULA_INJECTION_PREFIXES = ("=", "+", "-", "@", "\t", "\r", "%", "|")


def sanitize_cell(value: str) -> str:
    """Neutralize spreadsheet formula injection vectors."""
    if not value:
        return ""
    val_str = str(value).strip()
    if val_str.startswith(FORMULA_INJECTION_PREFIXES):
        return "'" + val_str
    return val_str


def export_leads_to_csv(json_path: str, output_csv: str):
    """Safely converts a JSON payload of leads into a clean, sanitized CSV."""
    if not os.path.isfile(json_path):
        print(f"[!] Error: File '{json_path}' not found.", file=sys.stderr)
        sys.exit(1)

    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    contacts = data.get("contacts", [])
    newsletters = data.get("newsletters", [])

    print(f"[*] Found {len(contacts)} contacts and {len(newsletters)} newsletter subscribers.")

    with open(output_csv, "w", newline="", encoding="utf-8-sig") as csv_out:
        writer = csv.writer(csv_out, quoting=csv.QUOTE_ALL)
        writer.writerow(["Type", "ID", "Timestamp (ISO)", "Name", "Email", "Topic / Source", "Message / Details"])

        for c in contacts:
            writer.writerow([
                "Contact Inquiry",
                sanitize_cell(c.get("id", "")),
                sanitize_cell(c.get("timestamp", "")),
                sanitize_cell(c.get("name", "")),
                sanitize_cell(c.get("email", "")),
                sanitize_cell(c.get("topic", "")),
                sanitize_cell(c.get("message", ""))
            ])

        for s in newsletters:
            writer.writerow([
                "Newsletter Lead",
                sanitize_cell(s.get("id", "")),
                sanitize_cell(s.get("timestamp", "")),
                "—",
                sanitize_cell(s.get("email", "")),
                sanitize_cell(s.get("source", "website")),
                "Student Community Updates"
            ])

    print(f"[✓] Successfully generated sanitized CSV: {output_csv}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 export_leads.py <input_leads.json> [output.csv]")
        sys.exit(1)

    in_file = sys.argv[1]
    out_file = sys.argv[2] if len(sys.argv) > 2 else f"kortex_leads_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    export_leads_to_csv(in_file, out_file)

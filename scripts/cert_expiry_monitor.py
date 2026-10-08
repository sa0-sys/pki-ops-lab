#!/usr/bin/env python3
"""Certificate expiry monitor: scans a directory of PEM certs and reports by urgency.

Usage: python3 cert_expiry_monitor.py <cert_dir> [--warn 30] [--crit 14] [--json]
Exit code: 0 all fine, 1 warnings present, 2 critical or expired present (cron/monitoring friendly).
Parses certificates with the openssl CLI, so there are no third-party dependencies.
"""
import argparse, json, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path


def read_cert(path: Path):
    out = subprocess.run(
        ["openssl", "x509", "-in", str(path), "-noout", "-subject", "-issuer", "-enddate", "-serial"],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        return {"file": path.name, "error": out.stderr.strip()}
    fields = dict(line.split("=", 1) for line in out.stdout.strip().splitlines())
    end = datetime.strptime(fields["notAfter"].strip(), "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
    return {
        "file": path.name,
        "subject": fields["subject"].strip(),
        "issuer": fields["issuer"].strip(),
        "serial": fields["serial"].strip(),
        "not_after": end.isoformat(),
        "days_left": (end - datetime.now(timezone.utc)).days,
    }


def classify(days, warn, crit):
    if days < 0:
        return "EXPIRED"
    if days <= crit:
        return "CRITICAL"
    if days <= warn:
        return "WARNING"
    return "OK"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cert_dir")
    ap.add_argument("--warn", type=int, default=30)
    ap.add_argument("--crit", type=int, default=14)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    rows = []
    for p in sorted(Path(a.cert_dir).glob("*.crt")) + sorted(Path(a.cert_dir).glob("*.pem")):
        r = read_cert(p)
        if "error" not in r:
            r["status"] = classify(r["days_left"], a.warn, a.crit)
        rows.append(r)

    rows.sort(key=lambda r: r.get("days_left", -10**9))
    if a.json:
        print(json.dumps(rows, indent=2))
    else:
        print(f"{'STATUS':<9}{'DAYS':>6}  {'EXPIRES':<11} SUBJECT")
        for r in rows:
            if "error" in r:
                print(f"{'ERROR':<9}{'-':>6}  {'-':<11} {r['file']}: {r['error']}")
            else:
                print(f"{r['status']:<9}{r['days_left']:>6}  {r['not_after'][:10]:<11} {r['subject']}")

    statuses = {r.get("status") for r in rows}
    sys.exit(2 if statuses & {"EXPIRED", "CRITICAL"} else 1 if "WARNING" in statuses else 0)


if __name__ == "__main__":
    main()

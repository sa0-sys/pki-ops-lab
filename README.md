# PKI Operations Lab

A small, self-directed lab that walks through day-to-day PKI operations on a local two-tier CA built with OpenSSL: build the hierarchy, issue, revoke, publish revocation data, validate, and watch for expiry.

Self-directed learning project. Not a production deployment. Everything runs locally; no real domains or public CAs are involved.

## What it covers

| Area | What the lab does | Script |
|---|---|---|
| CA hierarchy | Root CA (RSA 4096) and issuing intermediate (pathlen:0), with a delegated OCSP signing certificate | `01_build_ca_hierarchy.sh` |
| Issuance | Server certificates with SAN, serverAuth EKU, CRL distribution point and OCSP (AIA) extensions | `02_issue_cert.sh` |
| Revocation | Revoke with a reason code, regenerate and publish the CRL | `03_revoke_and_publish_crl.sh` |
| Validation | Chain verification, CRL-checked verification, and live OCSP query against a local responder | `04_validate.sh`, `05_ocsp_responder.sh` |
| Lifecycle monitoring | Expiry scanner with warning/critical thresholds and cron-friendly exit codes | `cert_expiry_monitor.py` |
| Operations docs | Runbook for issuance, renewal, revocation and trust-chain troubleshooting | `docs/runbook.md` |

## Run it

```bash
export CA_BASE=$PWD/ca
bash scripts/01_build_ca_hierarchy.sh
bash scripts/02_issue_cert.sh app1.lab.local 90
bash scripts/02_issue_cert.sh app2.lab.local 10      # short-lived, to trigger the monitor
bash scripts/02_issue_cert.sh bad.lab.local 90
bash scripts/03_revoke_and_publish_crl.sh bad.lab.local keyCompromise
bash scripts/05_ocsp_responder.sh &                   # leave running
bash scripts/04_validate.sh bad.lab.local             # chain OK, CRL: revoked, OCSP: revoked
bash scripts/04_validate.sh app1.lab.local            # all good
python3 scripts/cert_expiry_monitor.py ca/issued
```

Requires OpenSSL 3.x and Python 3.8+. No third-party Python packages.

## Not covered (yet)

- Enrolment protocols: SCEP, CMPv2, ACME
- Microsoft AD CS or a commercial CA platform (DigiCert, GlobalSign)
- HSM-backed CA keys (keys here are files on disk, which is fine for a lab and wrong for production)
- Automated renewal and deployment
- Alerting integration (Splunk, Grafana, ITSM ticket creation)

## Notes

`ca/` is git-ignored: it holds private keys generated on your machine.

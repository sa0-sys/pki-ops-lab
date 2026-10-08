# PKI Operations Runbook (lab)

Scope: the two-tier lab CA in this repo. Written the way an operational SOP would be, so each task has trigger, steps, verification and rollback.

## 1. Issue a certificate
**Trigger:** request from an application team with FQDN and owner.
1. Confirm the requester owns the FQDN and record the ticket reference.
2. Generate key and CSR on the requesting host (private key never leaves it). In the lab: `02_issue_cert.sh <fqdn> <days>`.
3. Check the issued cert: SAN matches the request, EKU is serverAuth, validity is within policy (90 days in this lab).
4. Verify the chain: `openssl verify -CAfile ca/intermediate/certs/chain.pem <cert>`.
5. Hand over the cert plus intermediate. Close the ticket with serial number and expiry date.

## 2. Renew
**Trigger:** monitor reports WARNING (30 days) or CRITICAL (14 days).
1. Run `cert_expiry_monitor.py` and identify the owner from the subject.
2. Issue a new certificate (section 1). Prefer a new key over reusing the old one.
3. Owner deploys it. Confirm the new serial is the one presented by the service.
4. Let the old certificate expire, or revoke it if the key was exposed.

## 3. Revoke
**Trigger:** key compromise, decommissioned service, wrong issuance.
1. Confirm the request comes from the certificate owner or security; log who and why.
2. `03_revoke_and_publish_crl.sh <fqdn> <reason>` (keyCompromise, cessationOfOperation, superseded...).
3. Publish the new CRL and check the OCSP responder now returns `revoked`.
4. Tell the owner, and note that clients with cached OCSP/CRL data may take until the next update to notice.

## 4. Troubleshooting validation failures
| Symptom | Likely cause | Check |
|---|---|---|
| `unable to get local issuer certificate` | Server not sending the intermediate, or client lacks the root | `openssl s_client -connect host:443 -showcerts`; count certs sent |
| `certificate has expired` | Renewal missed, or wrong cert deployed | `openssl x509 -noout -enddate -in cert`; compare serial on the wire |
| `Hostname mismatch` | SAN does not include the name clients use | `openssl x509 -noout -ext subjectAltName -in cert` |
| `certificate revoked` | CRL/OCSP says revoked | `04_validate.sh <fqdn>`; confirm revocation reason in `index.txt` |
| Works in one client, fails in another | Different trust stores, or one client does not fetch the intermediate | Compare trust stores; always serve the full chain |
| OCSP `unauthorized` / verify failure | Responder cert missing OCSPSigning EKU or not issued by the CA | Inspect `ocsp.crt` extensions |

## 5. Incident write-up template
Impact and affected services, timeline, root cause, fix, what prevents a repeat (monitoring threshold, process change, documentation).

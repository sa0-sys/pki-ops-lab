#!/usr/bin/env bash
# Revoke a certificate and regenerate the CRL. Usage: 03_revoke_and_publish_crl.sh <fqdn> [reason]
set -euo pipefail
BASE="${CA_BASE:-$(pwd)/ca}"; FQDN="$1"; REASON="${2:-keyCompromise}"
openssl ca -config "$BASE/intermediate/openssl.cnf" -revoke "$BASE/issued/$FQDN.crt" -crl_reason "$REASON" 2>/dev/null
openssl ca -config "$BASE/intermediate/openssl.cnf" -gencrl -out "$BASE/intermediate/crl/intermediate.crl.pem" 2>/dev/null
openssl crl -in "$BASE/intermediate/crl/intermediate.crl.pem" -noout -text | grep -E "Last Update|Next Update|Serial Number|Revocation Date|Reason"

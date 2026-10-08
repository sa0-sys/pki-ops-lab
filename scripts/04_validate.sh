#!/usr/bin/env bash
# Validate a cert three ways: chain, CRL, OCSP. Usage: 04_validate.sh <fqdn>
set -uo pipefail
BASE="${CA_BASE:-$(pwd)/ca}"; FQDN="$1"; C="$BASE/issued/$FQDN.crt"
echo "--- chain only"
openssl verify -CAfile "$BASE/intermediate/certs/chain.pem" "$C"
echo "--- chain + CRL check"
cat "$BASE/intermediate/certs/chain.pem" "$BASE/intermediate/crl/intermediate.crl.pem" > "$BASE/.verify_bundle.pem" 2>/dev/null
openssl verify -crl_check -CAfile "$BASE/.verify_bundle.pem" "$C" 2>&1 || true
echo "--- OCSP (needs 05_ocsp_responder.sh running)"
openssl ocsp -CAfile "$BASE/intermediate/certs/chain.pem" -issuer "$BASE/intermediate/certs/intermediate.crt" \
  -cert "$C" -url http://localhost:2560 -resp_text 2>&1 | grep -E "Cert Status|Revocation Time|Reason|This Update|Next Update|Response verify" || true

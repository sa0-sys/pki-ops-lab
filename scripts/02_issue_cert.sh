#!/usr/bin/env bash
# Issue a server certificate with a SAN from the intermediate. Usage: 02_issue_cert.sh <fqdn> [days]
set -euo pipefail
BASE="${CA_BASE:-$(pwd)/ca}"; FQDN="$1"; DAYS="${2:-90}"
OUT="$BASE/issued"; mkdir -p "$OUT"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$OUT/$FQDN.key" 2>/dev/null
openssl req -new -key "$OUT/$FQDN.key" -subj "/CN=$FQDN/O=PKI Ops Lab" \
  -addext "subjectAltName=DNS:$FQDN" -out "$OUT/$FQDN.csr"
openssl ca -batch -config "$BASE/intermediate/openssl.cnf" -extensions server_cert -days "$DAYS" -notext \
  -in "$OUT/$FQDN.csr" -out "$OUT/$FQDN.crt" 2>/dev/null
openssl verify -CAfile "$BASE/intermediate/certs/chain.pem" "$OUT/$FQDN.crt"

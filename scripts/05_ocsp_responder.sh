#!/usr/bin/env bash
# Run a local OCSP responder for the issuing CA (foreground). Ctrl+C to stop.
set -euo pipefail
BASE="${CA_BASE:-$(pwd)/ca}"
openssl ocsp -port 2560 -text -index "$BASE/intermediate/index.txt" \
  -CA "$BASE/intermediate/certs/chain.pem" \
  -rkey "$BASE/intermediate/private/ocsp.key" -rsigner "$BASE/intermediate/certs/ocsp.crt"

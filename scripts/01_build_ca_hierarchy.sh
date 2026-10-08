#!/usr/bin/env bash
# Builds a two-tier CA hierarchy (root + issuing intermediate) with OpenSSL, plus a delegated OCSP signer.
set -euo pipefail
BASE="${1:-$(pwd)/ca}"
rm -rf "$BASE"; mkdir -p "$BASE"/{root,intermediate}/{private,certs,newcerts,crl,csr}
for t in root intermediate; do
  touch "$BASE/$t/index.txt"; echo 1000 > "$BASE/$t/serial"; echo 1000 > "$BASE/$t/crlnumber"
done

cat > "$BASE/root/openssl.cnf" <<CNF
[ ca ]
default_ca = CA_default
[ CA_default ]
dir = $BASE/root
database = \$dir/index.txt
new_certs_dir = \$dir/newcerts
serial = \$dir/serial
crlnumber = \$dir/crlnumber
private_key = \$dir/private/root.key
certificate = \$dir/certs/root.crt
default_md = sha256
default_days = 3650
default_crl_days = 30
policy = policy_any
[ policy_any ]
commonName = supplied
organizationName = optional
[ req ]
distinguished_name = dn
prompt = no
[ dn ]
CN = Lab Root CA
O = PKI Ops Lab
[ v3_root ]
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
[ v3_intermediate ]
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
crlDistributionPoints = URI:http://localhost:8080/intermediate.crl.pem
authorityInfoAccess = OCSP;URI:http://localhost:2560
CNF

cat > "$BASE/intermediate/openssl.cnf" <<CNF
[ ca ]
default_ca = CA_default
[ CA_default ]
dir = $BASE/intermediate
database = \$dir/index.txt
new_certs_dir = \$dir/newcerts
serial = \$dir/serial
crlnumber = \$dir/crlnumber
private_key = \$dir/private/intermediate.key
certificate = \$dir/certs/intermediate.crt
default_md = sha256
default_days = 90
default_crl_days = 7
policy = policy_any
copy_extensions = copy
unique_subject = no
[ policy_any ]
commonName = supplied
organizationName = optional
[ server_cert ]
basicConstraints = CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
crlDistributionPoints = URI:http://localhost:8080/intermediate.crl.pem
authorityInfoAccess = OCSP;URI:http://localhost:2560
[ ocsp_cert ]
basicConstraints = CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
CNF

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$BASE/root/private/root.key" 2>/dev/null
chmod 400 "$BASE/root/private/root.key"
openssl req -new -x509 -key "$BASE/root/private/root.key" -config "$BASE/root/openssl.cnf" \
  -extensions v3_root -days 7300 -sha256 -out "$BASE/root/certs/root.crt"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$BASE/intermediate/private/intermediate.key" 2>/dev/null
chmod 400 "$BASE/intermediate/private/intermediate.key"
openssl req -new -key "$BASE/intermediate/private/intermediate.key" -subj "/CN=Lab Issuing CA/O=PKI Ops Lab" \
  -out "$BASE/intermediate/csr/intermediate.csr"
openssl ca -batch -config "$BASE/root/openssl.cnf" -extensions v3_intermediate -days 3650 -notext \
  -in "$BASE/intermediate/csr/intermediate.csr" -out "$BASE/intermediate/certs/intermediate.crt" 2>/dev/null
cat "$BASE/intermediate/certs/intermediate.crt" "$BASE/root/certs/root.crt" > "$BASE/intermediate/certs/chain.pem"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$BASE/intermediate/private/ocsp.key" 2>/dev/null
openssl req -new -key "$BASE/intermediate/private/ocsp.key" -subj "/CN=Lab OCSP Responder/O=PKI Ops Lab" \
  -out "$BASE/intermediate/csr/ocsp.csr"
openssl ca -batch -config "$BASE/intermediate/openssl.cnf" -extensions ocsp_cert -days 365 -notext \
  -in "$BASE/intermediate/csr/ocsp.csr" -out "$BASE/intermediate/certs/ocsp.crt" 2>/dev/null

openssl verify -CAfile "$BASE/root/certs/root.crt" "$BASE/intermediate/certs/intermediate.crt"
echo "CA hierarchy built in $BASE"

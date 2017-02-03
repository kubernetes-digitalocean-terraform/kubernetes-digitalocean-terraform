#!/bin/bash

SECRETS_DIR=$PWD/secrets
CFSSL_DIR=$(dirname "${BASH_SOURCE[0]}")

template=$(cat $CFSSL_DIR/server.json | sed "s/\${SERVERNAME}/$1/g")

echo $template | cfssl gencert -ca=$SECRETS_DIR/ca.pem \
    -ca-key=$SECRETS_DIR/ca-key.pem \
    -config=$CFSSL_DIR/ca-config.json \
    -profile=server \
    -hostname="$2" - | cfssljson -bare $SECRETS_DIR/$1

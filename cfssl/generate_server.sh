#!/bin/bash

SECRETS_DIR=$PWD/secrets

template=$(cat $PWD/cfssl/server.json | sed "s/\${SERVERNAME}/$1/g")

echo $template | cfssl gencert -ca=$SECRETS_DIR/ca.pem \
    -ca-key=$SECRETS_DIR/ca-key.pem \
    -config=$PWD/cfssl/ca-config.json \
    -profile=server \
    -hostname="$2" - | cfssljson -bare $SECRETS_DIR/$1

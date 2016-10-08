#!/bin/bash

SECRETS_DIR=$PWD/secrets

cfssl gencert -ca=$SECRETS_DIR/ca.pem \
    -ca-key=$SECRETS_DIR/ca-key.pem \
    -config=$PWD/cfssl/ca-config.json \
    -profile=client $PWD/cfssl/client.json | cfssljson -bare $SECRETS_DIR/client-$1

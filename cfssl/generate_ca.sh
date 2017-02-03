#!/bin/bash

SECRETS_DIR=$PWD/secrets
CFSSL_DIR=$(dirname "${BASH_SOURCE[0]}")

cfssl gencert -initca $CFSSL_DIR/ca-csr.json | cfssljson -bare $SECRETS_DIR/ca -

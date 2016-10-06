#!/bin/bash

SECRETS_DIR=$PWD/secrets

cfssl gencert -initca $PWD/cfssl/ca-csr.json | cfssljson -bare $SECRETS_DIR/ca -

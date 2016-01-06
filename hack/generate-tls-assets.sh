#!/bin/bash

###############################################################################
#
# Generate TLS Assets
#
# For educational purposes!
# In real life, you should be more careful how and where do you generate and
# store your certificates </disclaimer>
#
###############################################################################

SECRETS_DIR=$PWD/secrets

openssl genrsa -out $SECRETS_DIR/ca-key.pem 2048
openssl req -x509 -new -nodes -key $SECRETS_DIR/ca-key.pem -days 10000 -out $SECRETS_DIR/ca.pem -subj "/CN=kube-ca"

sed -e "s/\${MASTER_HOST}/$1/" < $PWD/hack/openssl.cnf.template > $SECRETS_DIR/openssl.cnf

openssl genrsa -out $SECRETS_DIR/apiserver-key.pem 2048
openssl req -new -key $SECRETS_DIR/apiserver-key.pem -out $SECRETS_DIR/apiserver.csr -subj "/CN=kube-apiserver" -config $SECRETS_DIR/openssl.cnf
openssl x509 -req -in $SECRETS_DIR/apiserver.csr -CA $SECRETS_DIR/ca.pem -CAkey $SECRETS_DIR/ca-key.pem -CAcreateserial -out $SECRETS_DIR/apiserver.pem -days 365 -extensions v3_req -extfile $SECRETS_DIR/openssl.cnf

openssl genrsa -out $SECRETS_DIR/worker-key.pem 2048
openssl req -new -key $SECRETS_DIR/worker-key.pem -out $SECRETS_DIR/worker.csr -subj "/CN=kube-worker"
openssl x509 -req -in $SECRETS_DIR/worker.csr -CA $SECRETS_DIR/ca.pem -CAkey $SECRETS_DIR/ca-key.pem -CAcreateserial -out $SECRETS_DIR/worker.pem -days 365

openssl genrsa -out $SECRETS_DIR/admin-key.pem 2048
openssl req -new -key $SECRETS_DIR/admin-key.pem -out $SECRETS_DIR/admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in $SECRETS_DIR/admin.csr -CA $SECRETS_DIR/ca.pem -CAkey $SECRETS_DIR/ca-key.pem -CAcreateserial -out $SECRETS_DIR/admin.pem -days 365


#!/bin/bash
set -o errexit
PUBLIC_KEY=$1
TOKEN=$2
. ./setup_terraform.sh $PUBLIC_KEY 
terraform init && terraform plan && terraform apply

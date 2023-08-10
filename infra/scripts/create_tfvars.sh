#!/bin/bash
# Use cloudfare to get my public IP address
MY_IP_ADDRESS=$(dig +short txt ch whoami.cloudflare @1.0.0.1)
SSO_ROLE_NAME=$(aws sts get-caller-identity | jq -r .Arn)

if [ ! -f vars.tfvars ]; then
    echo "vars.tfvars not found. Creating..."
    cat <<EOF > vars.tfvars
my_ip_address=${MY_IP_ADDRESS}
sso_role_name=${SSO_ROLE_NAME}
EOF
    echo "vars.tfvars created."
else
    echo "vars.tfvars found. Exiting..."
fi

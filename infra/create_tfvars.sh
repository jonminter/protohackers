#!/bin/bash
# Use cloudfare to get my public IP address
MY_IP_ADDRESS=$(dig +short txt ch whoami.cloudflare @1.0.0.1)

if [ ! -f vars.tfvars ]; then
    echo "vars.tfvars not found. Creating..."
    # read from std into SSO_ROLE_NAME
    read -p "SSO Role Name: " SSO_ROLE_NAME

    cat <<EOF > vars.tfvars
my_ip_address=${MY_IP_ADDRESS}
sso_role_name=${SSO_ROLE_NAME}
EOF
    echo "vars.tfvars created."
else
    echo "vars.tfvars found. Exiting..."
fi

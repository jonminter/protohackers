#!/bin/bash

set -eo pipefail

PARENT_DIR_OF_THIS_FILE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $PARENT_DIR_OF_THIS_FILE/..

matches=$(cat ~/.aws/config | grep -c protohackers_ssh || true)
if [ $matches -eq 0 ]; then
    echo "No profile found for protohackers. Creating..."

    ROLE_ARN=$(terraform output -raw ssh_role_arn)

    read -p "Source Profile: " SOURCE_PROFILE

    cat <<EOF >> ~/.aws/config
[profile protohackers_ssh]
role_arn = ${ROLE_ARN}
source_profile = ${SOURCE_PROFILE}
EOF

    echo "Profile created."
else
    echo "Profile found. Exiting..."
fi

echo "To use this profile, run:"
echo "export AWS_PROFILE=protohackers_ssh"
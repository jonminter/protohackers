#!/bin/bash

set -eo pipefail

PARENT_DIR_OF_THIS_FILE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $PARENT_DIR_OF_THIS_FILE/..

ROLE_ARN=$(terraform output -raw ssh_role_arn)
echo "Using role arn: $ROLE_ARN"

read -p "Please provice the 'Source Profile' that can assume this role: " SOURCE_PROFILE

aws configure set --profile protohackers_ssh role_arn $(terraform output -raw ssh_role_arn)
aws configure set --profile protohackers_ssh source_profile $SOURCE_PROFILE

echo "To use this profile, run:"
echo "export AWS_PROFILE=protohackers_ssh"
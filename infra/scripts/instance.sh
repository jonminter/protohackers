#!/bin/bash

PARENT_DIR_OF_THIS_FILE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $PARENT_DIR_OF_THIS_FILE/..
if [ "$1" == "ip" ]; then
    terraform output -raw instance_ip
elif [ "$1" == "id" ]; then
    terraform output -raw instance_id
else
    echo "Usage: $0 [ip|id]"
fi
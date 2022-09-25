#!/bin/bash
set -uxo pipefail


docker exec sftp create-sftp-user $1:$2:::$3 | grep "already exists"
if [ $? -eq 0 ]; then
	echo "User exists !!"
	exit 1
else
	exit 0
fi

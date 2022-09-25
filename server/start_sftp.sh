#!/bin/bash

. ./.env

docker run -p $B_PORT:22 -d --rm --name sftp atmoz/sftp $B_USERID:$B_PASS:::$B_DIR

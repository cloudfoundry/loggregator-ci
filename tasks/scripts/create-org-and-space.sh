#!/bin/bash
set -ex
password=$(bosh int vars-store/$VARS_STORE_FILE --path=/cf_admin_password)

cf login -a api.$SYSTEM_DOMAIN -u admin -p $password -o system --skip-ssl-validation

set +e
cf org $ORG
set -e
if [ $? -eq 0 ]; then
  cf create-org $ORG
fi
cf target -o $ORG

set +e
cf space $SPACE
set -e
if [ $? -eq 0 ]; then
  cf create-space $SPACE
fi
cf target -s $SPACE

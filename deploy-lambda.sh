#!/bin/bash
#
# deploy-lambda.sh
# Zip and deploy lambda function
#

set -o errexit

if [ $# -lt 2 ]
then
  echo 'Missing required parameters'
  echo "Usage $0 <function> <role_stack_name>"
  exit 1
fi

func="$1"
role_stack_name="$2"

file="./${func}.js"
zip="./${func}.zip"
description="Cloud Formation Custom Resource: $func"


role_arn() {
  aws cloudformation describe-stacks \
    --stack-name $role_stack_name \
    | jq '.Stacks[0].Outputs[]| select(.OutputKey=="RoleArn")|.OutputValue' \
    | tr -d \"
}

zip_package() {
  zip -qr $zip $file
}

function_exists() {
  echo "Checking for function $func"
  aws lambda get-function \
    --function-name $func > /dev/null 2>&1

}

create_function() {
  echo "Getting ARN for role $role_stack_name"
  local role_arn=$(role_arn)
  echo "CREATE function $func"
  aws lambda create-function \
    --role $role_arn \
    --runtime nodejs \
    --function-name $func  \
    --description "$description" \
    --handler ${func}.handler \
    --timeout 10 \
    --memory-size 128 \
    --zip-file fileb://$zip
}

update_function() {
  echo "UPDATING function $func"
  aws lambda update-function-code \
    --function-name $func  \
    --zip-file fileb://$zip
}

# main
zip_package
if function_exists; then
  update_function
else
  create_function
fi


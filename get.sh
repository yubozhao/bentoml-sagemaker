#!/usr/bin/env bash

if ! command -v aws &> /dev/null
then
    echo "aws could not be found"
    exit
fi

if [ "$#" -eq 1 ]; then
  DEPLOYMENT_NAME=$1
else
  echo "Must provide deployment name"
  exit 1
fi

echo "Get resource names"
read -r MODEL_REPO_NAME MODEL_NAME ENDPOINT_CONFIG_NAME ENDPOINT_NAME <<<$(python sagemaker/generate_resource_names.py $DEPLOYMENT_NAME)

echo "Get Sagemaker endpoint description"
aws sagemaker describe-endpoint --endpoint-name $ENDPOINT_NAME | python get_json_value_from_return_struct.py

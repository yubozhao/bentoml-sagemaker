#!/usr/bin/env bash

if ! command -v aws &> /dev/null
then
    echo "aws could not be found"
    exit
fi

if [ "$#" -eq 1 ]; then
  DEPLOYMENT_NAME=$1
else
  echo "Must provide sagemaker deployment name"
  exit 1
fi

echo "Get resource names"
read -r MODEL_REPO_NAME MODEL_NAME ENDPOINT_CONFIG_NAME ENDPOINT_NAME <<<$(python sagemaker/generate_resource_names.py $DEPLOYMENT_NAME)

aws sagemaker delete-endpoint --endpoint-name $ENDPOINT_NAME | python get_json_valule_from_return_struct.py
aws sagemaker delete-endpoint-config --endpoint-config-name $ENDPOINT_CONFIG_NAME | python get_json_valule_from_return_struct.py
aws sagemaker delete-model --model-name $MODEL_NAME | python get_json_valule_from_return_struct.py

# Use this command to delete the ECR repository
#aws ecr delete-repository --repository-name $MODEL_REPO_NAME --force

#!/usr/bin/env bash
set -e

if ! command -v aws &> /dev/null
then
    echo "aws command could not be found"
    exit
fi

if [ "$#" -eq 3 ]; then
  DEPLOYMENT_NAME=$1
  BENTO_BUNDLE_PATH=$2
  API_NAME=$3
  CONFIG_JSON=sagemaker_config.json
elif [ "$#" -eq 4 ]; then
  DEPLOYMENT_NAME=$1
  BENTO_BUNDLE_PATH=$2
  API_NAME=$3
  CONFIG_JSON=$4
else
  echo "Must provide deployment name, bundle path and API name"
  exit 1
fi


# Set resource names
echo "Set resource names"
read -r MODEL_REPO_NAME MODEL_NAME ENDPOINT_CONFIG_NAME ENDPOINT_NAME <<<$(python sagemaker/generate_resource_names.py $DEPLOYMENT_NAME)

# Get deployment configuration from configuration file
echo "Get Sagemaker configuration from configuration file"
read -r REGION TIMEOUT NUM_OF_WORKERS INSTANCE_TYPE INITIAL_INSTANCE_COUNT ENABLE_DATA_CAPTURE DATA_CAPTURE_S3_PREFIX DATA_CAPTURE_SAMPLE_PERCENT <<<$(python get_configuration_value.py $CONFIG_JSON)

# Generate Sagemaker deployable
echo "Generate deployable for Sagemaker"
read -r DEPLOYABLE_PATH BENTO_NAME BENTO_VERSION <<<$(python ./sagemaker/generate_deployable.py $BENTO_BUNDLE_PATH .)

# Get ARN and Account Id
echo "Get ARN and account ID"
read -r ARN AWS_ACCOUNT_ID <<<$(python sagemaker/get_arn_from_aws.py)

# Create ECR repository
echo "Create ECR repository"
read -r REGISTRY_ID REGISTRY_URI <<<$(aws ecr create-repository --repository-name $MODEL_REPO_NAME | python get_json_value_from_return_struct.py repository.registryId repository.repositoryUri)

# login docker
echo "Docker login with ECR"
aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build docker image and push to ECR
IMAGE_TAG=$(python ./sagemaker/generate_docker_image_tag.py $REGISTRY_URI $BENTO_NAME $BENTO_VERSION)
echo "Building docker image $IMAGE_TAG"
docker build $DEPLOYABLE_PATH -t $IMAGE_TAG

## login docker
echo "Log in and push image to ECR"
aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker push $IMAGE_TAG

# Create Sagemaker model
echo "Create Sagemaker model"
MODEL_INFO=$(python ./sagemaker/generate_model_info.py $MODEL_NAME $IMAGE_TAG $API_NAME $TIMEOUT $NUM_OF_WORKERS)
read -r MODEL_ARN <<<$(aws sagemaker create-model --model-name $MODEL_NAME --primary-container $MODEL_INFO --execution-role-arn $ARN | python get_json_value_from_return_struct.py ModelArn)

# Create Sagemaker endpoint config
echo "Create Sagemaker endpoint config"
PRODUCTION_VARIANTS=$(python ./sagemaker/generate_endpoint_config.py $MODEL_NAME $INITIAL_INSTANCE_COUNT $INSTANCE_TYPE)
if [ "$ENABLE_DATA_CAPTURE" = false]; then
  read -r ENDPOINT_CONFIG_ARN <<<$(aws sagemaker create-endpoint-config --endpoint-config-name $ENDPOINT_CONFIG_NAME --production-variants $PRODUCTION_VARIANTS | python get_json_value_from_return_struct.py EndpointConfigArn)
else
  DATA_CAPTURE_CONFIG=$(python ./sagemaker/generate_data_capture_config.py $DATA_CAPTURE_SAMPLE_PERCENT $DATA_CAPTURE_S3_PREFIX)
  read -r ENDPOINT_CONFIG_ARN <<<$(aws sagemaker create-endpoint-config --endpoint-config-name $ENDPOINT_CONFIG_NAME --production-variants $PRODUCTION_VARIANTS --data-capture-config $DATA_CAPTURE_CONFIG | python get_json_value_from_return_struct.py EndpointConfigArn)
fi

# Create Sagemaker endpoint
echo "Create Sagemaker endpoint"
read -r ENDPOINT_ARN <<<$(aws sagemaker create-endpoint --endpoint-name $ENDPOINT_NAME --endpoint-config-name $ENDPOINT_CONFIG_NAME | python get_json_value_from_return_struct.py EndpointArn)

exit 0

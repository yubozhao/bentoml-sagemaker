#!/usr/bin/env bash


if ! command -v aws &> /dev/null
then
    echo "aws command could not be found"
    exit
fi

if [ "$#" -eq 3]; then
  BENTO_BUNDLE_PATH=$1
  DEPLOYMENT_NAME=$2
  API_NAME=$3
  CONFIG_JSON=sagemaker_config.json
elif [ "$#" -eq 4]; then
  BENTO_BUNDLE_PATH=$1
  DEPLOYMENT_NAME=$2
  API_NAME=$3
  CONFIG_JSON=$4
else
  echo "Must provide deployment name, bundle path and API name"
  exit 1
fi


# Set resources names
MODEL_REPO_NAME=$DEPLOYMENT_NAME-repo
MODEL_NAME=$DEPLOYMENT_NAME-model
ENDPOINT_CONFIG_NAME=$DEPLOYMENT_NAME-endpoint-config
ENDPOINT_NAME=$DEPLOYMENT_NAME-endpoint


# Get configuration from configuration file
read -r REGION TIMEOUT INSTANCE_TYPE INITIAL_INSTANCE_COUNT ENABLE_DATA_CAPTURE DATA_CAPTURE_S3_PREFIX DATA_CAPTURE_SAMPLE_PERCENT <<<$(python get_configuration_value.py $CONFIG_JSON)

# Get ARN and Account Id
ARN=$(aws sts get-caller-identity | python get_json_value_from_return_struct.py Arn)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity | python get_json_value_from_return_struct.py Account)

# Create ECR repository
REGISTRY_ID=$(aws ecr create-repository --repository-name $MODEL_REPO_NAME | python get_json_value_from_return_struct.py repository.registryId)

# login docker
aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Generate Sagemaker deployable
DEPLOYABLE_PATH=$(python ./bentoml_sagemaker/generate_deployable.py $BENTO_BUNDLE_PATH .)

# Build docker image and push to ECR
IMAGE_TAG=$(python ./bentoml_sagemaker/genearate_docker_image_tag.py $BENTO_BUNDLE_PATH $REGISTRY_ADDRESS)
docker build $DEPLOYABLE_PATH -t $IMAGE_TAG

## login docker
aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker push $IMAGE_TAG

# Create Sagemaker model
MODEL_INFO=$(python ./bentoml_sagemaker/generate_model_info.py $IMAGE_TAG $API_NAME $TIMEOUT)
aws sagemaker create-model --model-name $MODEL_NAME --primary-container $MODEL_INFO --execution-role-arn $ARN

# Create Sagemaker endpoint config
PRODUCTION_VARIANTS=$(python ./bentoml_sagemaker/generate_endpoint_config.py $MODEL_NAME $INITIAL_INSTANCE_COUNT $INSTANCE_TYPE)
if [ "$ENABLE_DATA_CAPTURE" = false]; then
  aws sagemaker create-endpoint-config --endpoint-config-name $ENDPOINT_CONFIG_NAME --production-variants $PRODUCTION_VARIANTS
  DATA_CAPTURE_CONFIG=$(python ./bentoml_sagemaker/generate_data_capture_config.py $DATA_CAPTURE_SAMPLE_PERCENT $DATA_CAPTURE_S3_PREFIX)
  aws sagemaker create-endpoint-config --endpoint-config-name $ENDPOINT_CONFIG_NAME --production-variants $PRODUCTION_VARIANTS --data-capture-config $DATA_CAPTURE_CONFIG
else
  DATA_CAPTURE_CONFIG=$(python ./bentoml_sagemaker/generate_data_capture_config.py $DATA_CAPTURE_SAMPLE_PERCENT $DATA_CAPTURE_S3_PREFIX)
  aws sagemaker create-endpoint-config --endpoint-config-name $ENDPOINT_CONFIG_NAME --production-variants $PRODUCTION_VARIANTS --data-capture-config $DATA_CAPTURE_CONFIG
fi

# Create Sagemaker endpoint
aws sagemaker create-endpoint --endpoint-name $ENDPOINT_NAME --endpoint-config-name $ENDPOINT_CONFIG_NAME

echo $ENDPOINT_NAME
exit 0

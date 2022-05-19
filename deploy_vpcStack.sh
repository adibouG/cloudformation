#!/bin/bash 

ENV=$1

if [ -z "$ENV" ]
then
    echo "vpc name  variable is missing."
    read -p "Enter a vpc name: " ENV
    echo "You entered $ENV"
    if [ -z "$ENV" ]
    then
        echo "vpc name missing."
        exit 1 
    fi
fi

FILE_NAME="CloudFormationTemplate_vpc-${ENV}.json"
STACK_NAME="vpc-${ENV}"
 
if [ -f "./${FILE_NAME}" ]; then
    echo "delete old template file"
    rm -rf "./${FILE_NAME}" 
fi

cp ./CloudFormationTemplate_vpc_model.json ./$FILE_NAME
sed -i'.backup' -e "s/{ENV}/$ENV/g" $FILE_NAME
echo "$FILE_NAME generated from CloudFormationTemplate_vpc_model.json success."

   
echo -e "upload to s3 start..."

if ! aws s3 cp ./$FILE_NAME s3://cloudformationtemplating ; then 
    
    echo -e "s3 upload failed..."
    exit 1
fi
   


shopt -s failglob
set -eu -o pipefail

echo "Checking if stack exists ..."

if ! aws cloudformation describe-stacks --region eu-west-1 --stack-name $STACK_NAME ; then

  echo -e "\nStack does not exist, creating ..."
  aws cloudformation create-stack \
    --region eu-west-1 \
    --stack-name $STACK_NAME \
    --template-url https://cloudformationtemplating.s3.eu-west-1.amazonaws.com/$FILE_NAME

  echo "Waiting for stack to be created ..."
  aws cloudformation wait stack-create-complete \
    --region eu-west-1 \
    --stack-name $STACK_NAME

else

  echo -e "\nStack exists, attempting update ..."

  echo -e "\nStack exists, attempting update ... using template file $FILE_NAME"
  set +e
  update_output=$( aws cloudformation update-stack \
    --region eu-west-1 \
    --stack-name $STACK_NAME \
    --template-url https://cloudformationtemplating.s3.eu-west-1.amazonaws.com/$FILE_NAME 2>&1)
  status=$?
  set -e

  echo "$update_output"

  if [ $status -ne 0 ] ; then

    # Don't fail for no-op update
    if [[ $update_output == *"ValidationError"* && $update_output == *"No updates"* ]] ; then
      echo -e "\nFinished create/update - no updates to be performed"
      exit 0
    else
      exit $status
    fi

  fi

  echo "Waiting for stack update to complete ..."
  aws cloudformation wait stack-update-complete \
    --region eu-west-1 \
    --stack-name $STACK_NAME 

fi

echo "Finished create/update vpc stack $STACK_NAME successfully!"
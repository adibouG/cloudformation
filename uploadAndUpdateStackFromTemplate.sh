#!/bin/bash

shopt -s failglob
set -eu -o pipefail

FILE_NAME=$1

if [ -z "${FILE_NAME}" ]; then
    read -p "enter the local cloudformationtemplate file name to use " FILE_NAME
fi

NAME_PATTERN="CloudFormationTemplate_"
EXT_PATTERN=".json"

STACK_NAME=`sed -e "s/${NAME_PATTERN}//g" -e "s/${EXT_PATTERN}//g"  <<<  $FILE_NAME`

echo "${STACK_NAME}"


echo -e "upload to s3 start..."

if ! aws s3 cp ./$FILE_NAME s3://cloudformationtemplating ; then 
    
    echo -e "s3 upload failed..."
    exit 1
fi


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

  echo -e "\nStack exists, attempting update $STACK_NAME  ..."

  echo -e "\nstack update using template file $FILE_NAME"
  set +e
  update_output=$( aws cloudformation update-stack \
    --region eu-west-1 \
    --stack-name $STACK_NAME \
    --template-url https://cloudformationtemplating.s3.eu-west-1.amazonaws.com/$FILE_NAME  2>&1)
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
rm -rf ./output.txt
echo "Finished create/update vpc stack $STACK_NAME successfully!"echo "Finished create/update successfully!"
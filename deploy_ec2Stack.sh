#!/bin/bash


#usage deploy_ec2Stack.sh <vpc> <subnet 1 or 2 or 3> <appname> <port> LISTENERPATH <keyName>

ENV="$1"
if [ -z "$ENV" ]
then
    echo "vpc name  variable is missing."
    read -p "Enter a vpc name: " ENV
    echo "You entered $ENV"
    if [ -z "$ENV" ]
    then
        exit 1 
    fi
fi

SUBNETNUMBER="$2"

if [ -z "$SUBNETNUMBER" ]
then
    echo "subnet level variable is missing."
    read -p "Enter a subnet number (1 or 2 or 3):" SUBNETNUMBER
    echo "You entered $SUBNETNUMBER"
    if [ -z "$SUBNETNUMBER" ]
    then
        exit 1 
    fi
fi

#get the vpcId subnetIds and lba arn
VPCID=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=vpc-$ENV --query "Vpcs[].VpcId" --output text |  awk 'match($0, /vpc-.*/  ) { print substr($0, RSTART, RLENGTH-1) } '`

if [ -z "$VPCID" ]
then
    echo "vpc not found."
    exit 1 
fi


SUBNET1=`aws cloudformation describe-stack-resources --stack-name vpc-$ENV --logical-resource-id sn${ENV}PriA${SUBNETNUMBER}  |  awk 'match($0, /subnet-.*/  ) { print substr($0, RSTART, RLENGTH-1) }'`

SUBNETID1=`sed -e 's/"// ' -e 's/,//' <<< "${SUBNET1}"  |  awk 'match($0, /subnet-.*/  ) { print substr($0, RSTART, RLENGTH ) }' `

SUBNET2=`aws cloudformation describe-stack-resources --stack-name vpc-$ENV --logical-resource-id sn${ENV}PriB${SUBNETNUMBER}  |  awk 'match($0, /subnet-.*/) { print substr($0, RSTART, RLENGTH-1 ) }'`

SUBNETID2=`sed -e 's/"//' -e 's/,//' <<< "${SUBNET2}" |  awk 'match($0, /subnet-.*/  ) { print substr($0, RSTART, RLENGTH ) }' `


if [ "$SUBNETNUMBER" = 1 ] 
then
    echo 'get the external load balancer'
    LBA_ARN=`aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' | grep ${ENV}-ext |  awk 'match($0, /arn:aws:elasticloadbalancing:.*/  ) { print substr($0, RSTART, RLENGTH-2) }'` 
else 
    LBA_ARN=`aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' | grep ${ENV}-int |  awk 'match($0, /arn:aws:elasticloadbalancing:.*/  ) { print substr($0, RSTART, RLENGTH-2) }'` 
fi

LBAARN=`sed -e 's/"//' <<< "$LBA_ARN"`

echo "$VPCID"
echo "$LBA_ARN"
echo "$LBAARN"
echo "$SUBNET1"
echo "$SUBNET2"
echo "$SUBNETID1"
echo "$SUBNETID2"

APPNAME="$3"
if [ -z "$APPNAME" ]
then
    echo "application name  variable is missing."
    read -p "Enter the application name: " NAME
    echo "You entered $NAME"
    if [ -z "$NAME" ]
     then
       exit 1
     fi
    APPNAME="$NAME"
fi

PORT="${4}"

if [ -z "${4}" ]
then
    echo "application port variable is missing."
    read -p "Enter the application port: " PORTNUM
    echo "You entered ${PORTNUM}"
    PORT="${PORTNUM}"
fi

LBAPATH="${5}"
if [ -z "${LBAPATH}" ]
then
    read -p "Enter a load balancer listener path ex: api/test/getData : " LBAPATH
    echo "You entered $LBAPATH"
    if [ -z "${LBAPATH}" ] 
    then
        exit 1 
    fi
fi

KEY="${6}"

if [ -n "$KEY" ]
then
    echo "keypair name is provided."
    KEYPAIR="${KEY}"  
else 
    KEYPAIR="${APPNAME}"
fi

FILE_NAME="CloudFormationTemplate_ec2-${APPNAME}-${ENV}.json"

STACK_NAME="ec2-${APPNAME}-${ENV}"

read -p "Do you want to deploy the application with the ec2 (y/n): " DEPLOY


if [[ "${DEPLOY}" == "y" ]] 
then

    read -p "Is the packerEc2AMIBuilerParameters.json file filled correctly with the aws access and secret key, the git repo url embedded with the user and password (y/n)" READY
    if [[ "${READY}" == "n" ]]  
    then
        read -p "Enter the aws access key : " AWSACCESSKEY
        read -p "Enter the aws secret key : " AWSSECRETKEY
        #read -p "Enter the git repo url with the access credential ex: https://userNameOrTokenName:UserPwsOrToken@gitlab.com/enzosystems/...) " GITURLWITHCREDENTIAL
        read -p "Enter the git repo url " GITURL
       read -p "Enter the git user " GITUSER
       read -p "Enter the git pwd " GITPWD
        read -p "Enter a ec2 type (if none, we use the t2 micro by default):" ECTYPE
        if [ -z "${ECTYPE}" ]  
        then
            ECTYPE="t2.micro"
        fi
        read -p "Enter a the application startup command (default is 'sudo node index.js' ):" APPSTARTCOMMAND
        
        
        echo "prepare packer parameter file to build an AMI from the git repo for the application deployment"
        
        # if [ -f "./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json" ]; then
            # echo "delete old parameter file"
            # rm -rf "./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json" 
        # fi
        
        if ! (sudo cp ./packerEc2AMIBuilderParameters_interactive.json ./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json) ; then
            cp ./packerEc2AMIBuilderParameters_interactive.json ./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        fi
        
        sed -i'.backup' -e "s/{ECTYPE}/${ECTYPE}/g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        sed -i'.backup' -e "s/{AWSACCESSKEY}/$AWSACCESSKEY/g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        sed -i'.backup' -e "s/{AWSSECRETKEY}/$AWSSECRETKEY/g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        #sed -i'.backup' -e "s|{GITURL}|${GITURLWITHCREDENTIAL}|g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        sed -i'.backup' -e "s|{GITUSER}|${GITUSER}|g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        sed -i'.backup' -e "s|{GITURL}|${GITURL}|g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        sed -i'.backup' -e "s|{GITPWD}|${GITPWD}|g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        sed -i'.backup' -e "s|{APPSTARTCOMMAND}|${APPSTARTCOMMAND}|g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        
    else   
    
        if ! (sudo cp ./packerEc2AMIBuilderParameters.json ./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json) ; then 
            cp ./packerEc2AMIBuilderParameters.json ./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
        fi
    
    fi
    
    sed -i'.backup' -e "s/{ENV}/$ENV/g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
    sed -i'.backup' -e "s/{APPNAME}/$APPNAME/g" packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json
    
    if [ $(which sudo) ] ; then 
        packer build --var-file=./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json ./packerEc2AMIBuilder.json 2>&1 |  sudo tee output.txt
    else 
        packer build --var-file=./packerEc2AMIBuilderParameters_${APPNAME}-${ENV}.json ./packerEc2AMIBuilder.json 2>&1 |  tee output.txt
    fi
    
    AMIID=$(tail -10 output.txt | head -10 | awk 'match($0, /ami-.*/) { print substr($0, RSTART, RLENGTH) }')
    
    if [ -z "$AMIID" ]
    then
        echo "Packer did not output the AMI id."
        exit 1
    else
        echo "Enzosystems environment deployment script with Packer success. generated the new AMI ID ${AMIID} for ${APPNAME} You can read the Packer build result in the files:\n ./packerBuildResult.json and output.txt"
    fi
fi


echo "Preparing the cloudformation template file from the model file"

if ! aws ec2 describe-key-pairs --key-names $KEYPAIR; then
    echo "create ssh key pair."
    aws ec2 create-key-pair --key-name=$KEYPAIR --query "KeyMaterial" --output text > $KEYPAIR.pem   
fi
 
if [ -f "./${FILE_NAME}" ]; then
    echo "delete old template file"
    rm -rf "./${FILE_NAME}" 
fi

if [ $(which sudo) ] ; then 
    sudo cp ./CloudFormationTemplate_ec2_model.json ./$FILE_NAME
else
    cp ./CloudFormationTemplate_ec2_model.json ./$FILE_NAME 
fi

echo "${SUBNETID1}"


SGGROUPID=`aws ec2 describe-security-groups --filters Name=group-name,Values=SG-${APPNAME}-${ENV} | grep GroupId |  awk 'match($0, /sg-.*/  ) { print substr($0, RSTART, RLENGTH-2) }'` 



if [ -n "${SGGROUPID}" ]; then
    echo "${SGGROUPID}"
    SGID=`sed -e 's/"//' <<< "$SGGROUPID" `
    echo "${SGID}"
    
   STRINGTOMATCH='{ "Ref" : "{NAME}SecurityGroup" }'
   sed -i'.backup' -e "s/$STRINGTOMATCH/${SGID}/g" $FILE_NAME
fi

sed -i'.backup' -e "s/{ENV}/$ENV/g" $FILE_NAME
sed -i'.backup' -e "s/{NAME}/$APPNAME/g" $FILE_NAME
sed -i'.backup' -e "s/{PORT}/$PORT/g" $FILE_NAME
sed -i'.backup' -e "s/{KEY}/$KEYPAIR/g" $FILE_NAME
sed -i'.backup' -e "s/{VPCID}/$VPCID/g" $FILE_NAME
sed -i'.backup' -e "s/{SUBNETID1}/$SUBNETID1/g" $FILE_NAME
sed -i'.backup' -e "s/{SUBNETID2}/$SUBNETID2/g" $FILE_NAME
sed -i'.backup' -e "s/{AMIID}/$AMIID/g" $FILE_NAME
sed -i'.backup' -e "s|{LOADBALANCERARN}|${LBAARN}|g" $FILE_NAME
sed -i'.backup' -e "s|{LISTENERPATH}|${LBAPATH}|g" $FILE_NAME

echo "$FILE_NAME generated from CloudFormationTemplate_ec2_model.json success."

      
echo "try to copy ${FILE_NAME}.backup in enzo-n1\\\\D2002 Enzo webservices\EnzoWebservices - Cloudformation\Cloudformation_newFiles\TemplatesBackup."

echo "lookup for the enzo-n1 drive letter "

DRIVE_LETTER=`net use | awk '/enzo-n1/ { print $2} '`

if [ -n DRIVE_LETTER ]; then

    BACKUP_PATH="${DRIVE_LETTER}\\D2002 Enzo webservices\EnzoWebservices - Cloudformation\\Cloudformation_newFiles\TemplatesBackup"
   
    echo "${BACKUP_PATH}"
    
    if [ -x "$(which sudo)" ] &&  sudo cp ./$FILE_NAME "${BACKUP_PATH}"; then 
        echo "copy to enzo-n1 done "
    else 
        if ! cp ./$FILE_NAME "${BACKUP_PATH}" ; then
            echo "copy to enzo-n1 failed"
        else 
            echo "copy to enzo-n1 done "
        fi
    fi
else 
    echo "lookup for the enzo-n1 drive letter failed"
fi

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
    
  echo "Finished update vpc stack $STACK_NAME successfully!"
  echo "Finished update successfully!"
  
else

  echo -e "\nStack exists, attempting update $STACK_NAME  ..."
 
  echo -e "\n check stack status "
  
  STACK_STATUS=`aws cloudformation describe-stacks --region eu-west-1 --stack-name $STACK_NAME | grep StackStatus |  awk 'match($0, /": ".*/  ) { print substr($0, RSTART, RLENGTH-2) }'` 
  echo "${STACK_STATUS}"

  STACKSTATUS=`sed -e 's/"//' -e 's/://'  <<< "$STACK_STATUS"` 
  echo "${STACKSTATUS}"
  
  if [[ ${STACKSTATUS} == *"ROLLBACK_INPROGRESS"* ]] ; then 

    
    echo "Waiting for stack rollback to complete ..."
    aws cloudformation wait stack-rollback-complete \
    --stack-name $STACK_NAME 

  fi
  
  
  if [[ ${STACKSTATUS} == *"ROLLBACK_COMPLETE"* ]] ; then 
  
    echo "delete stack before continue complete ..."
    aws cloudformation delete-stack \
    --stack-name $STACK_NAME 
    
    echo "Waiting for stack delete to complete ..."
    aws cloudformation wait stack-delete-complete \
    --stack-name $STACK_NAME 
    
    echo "recreate stack 
    ..."
    aws cloudformation create-stack \
    --region eu-west-1 \
    --stack-name $STACK_NAME \
    --template-url https://cloudformationtemplating.s3.eu-west-1.amazonaws.com/$FILE_NAME
    
    echo "Waiting for stack to be created ..."
    aws cloudformation wait stack-create-complete \
        --region eu-west-1 \
        --stack-name $STACK_NAME 
  
  else
   
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
            echo -e "\nFinished update - no updates to be performed"
            exit 0
        else
            exit $status
        fi
    fi

    echo "Waiting for stack update to complete ..."
    
    aws cloudformation wait stack-update-complete \
        --region eu-west-1 \
        --stack-name $STACK_NAME 
    
    echo "Finished update vpc stack $STACK_NAME successfully!"
    echo "Finished update successfully!"
  fi
fi  

rm -rf ./output.txt

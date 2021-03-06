#!/bin/bash
export PATH=$PATH:/var/jenkins_home/bin

oc login -u$USER_NAME -p$USER_PASSWD --server=$OSE_SERVER --insecure-skip-tls-verify &&
echo "Logged as user: $USER_NAME - $OSE_SERVER"
oc project $DEVEL_PROJ_NAME &&
echo "Using project $DEVEL_PROJ_NAME"

IS_NAME=`oc get is| grep $APP_NAME | tail -1 | awk '{print $1}'`
echo "IS_NAME: $IS_NAME"

#get full name of the image
FULL_IMAGE_NAME=`oc describe is ${IS_NAME} | grep -a1 "Tag" | tail -1 | awk '{print $6}'` &&
echo "FULL_IMAGE_NAME: $FULL_IMAGE_NAME"

#Tag to promote to QA
oc tag $FULL_IMAGE_NAME $DEVEL_PROJ_NAME/${IS_NAME}:promote &&
echo "oc tag $FULL_IMAGE_NAME $DEVEL_PROJ_NAME/${IS_NAME}:promote"

#This should automatically initiate deployment
oc project $QA_PROJ_NAME &&
echo "Using project $QA_PROJ_NAME"

#Find the DeploymentConfig to see if this is a new deployment or just needs an update
DC_ID=`oc get dc --no-headers | grep $APP_NAME | tail -1 | awk '{print $1}'` &&
echo "DC_ID: $DC_ID"

echo "DEBUG"
echo "DEVEL_PROJ_NAME: $DEVEL_PROJ_NAME"
echo "IS_NAME: ${IS_NAME}"
echo "APP_NAME: ${APP_NAME}"
echo "LABELS: ${LABELS}"
echo "user: $USER_NAME"
echo "Who am I? $(oc whoami)"
echo "oc new-app $DEVEL_PROJ_NAME/${IS_NAME}:promote --name=$APP_NAME -l $LABELS &&"

if [[ -z "$DC_ID" ]]; then
	oc new-app $DEVEL_PROJ_NAME/${IS_NAME}:promote --name=$APP_NAME -l $LABELS &&
	SVC_ID=`oc get svc | tail -1 | awk '{print $1}'`
	echo "SVC_ID: $SVC_ID"
	oc expose service $SVC_ID --hostname=$APP_HOSTNAME
fi

#find the new rc based on the FULL_IMAGE_NAME=$FULL_IMAGE_NAME
RC_ID=""
attempts=75
count=0
while [ -z "$RC_ID" -a $count -lt $attempts ]; do
	RC_ID=`oc get rc | grep $FULL_IMAGE_NAME | awk '{print $1}'`
	echo "RC_ID: $RC_ID"
	count=$(($count+1))
	sleep 5
done

if [ -z "$RC_ID" ]; then
  echo "Fail: App deployment was not successful"
  exit 1
fi

#Scale the app to 1 pod (just to make sure)
scale_result=`oc scale rc $RC_ID --replicas=1| awk '{print $3}'`

if [ $scale_result != "scaled" ]; then
  echo "Fail: Scaling not successful"
  exit 1
fi

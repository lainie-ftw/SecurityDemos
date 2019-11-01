#!/bin/bash

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

echo '*** Please enter the cluster GUID: ***'
read CLUSTER_GUID

oc login https://master."${CLUSTER_GUID}".example.opentlc.com -u admin -p r3dh4t1!
oc project ocp-workshop

echo "*** Logged in. ***"

oc delete all -l app=nexus

oc tag --source=docker sonatype/nexus3:latest ocp-workshop/nexus:latest
oc label is nexus app=nexus

oc new-app nexus:latest
oc rollout status dc/nexus
oc expose svc/nexus

echo "*** Old Nexus deleted, new Nexus deployed. Waiting a minute before we try to get the pod so we can do Nexus setup... ***"
sleep 5

NEXUS_POD=$(oc get pod -l app=nexus -o name --field-selector status.phase=Running)
ADMIN_PW=$(oc rsh "${NEXUS_POD}" cat nexus-data/admin.password)

curl -X PUT http://nexus-ocp-workshop.apps."${CLUSTER_GUID}".example.opentlc.com/service/rest/beta/security/users/admin/change-password -u admin:"${ADMIN_PW}" -H 'accept: application/json' -H 'Content-Type: text/plain' -d 'admin123'

echo "*** Admin password changed for Nexus. ***"

#set up the 'anonymous' script, from here: https://raw.githubusercontent.com/sonatype-nexus-#community/nexus-scripting-examples/master/simple-shell-example/anonymous.json

curl -X POST http://nexus-ocp-workshop.apps."${CLUSTER_GUID}".example.opentlc.com/service/rest/v1/script -H 'accept: application/json' -H 'Content-Type: application/json' -d '{ \"name\": \"anonymous\", \"type\": \"groovy\", \"content\": \"security.setAnonymousAccess(true)\"}'

#run the 'anonymous' script

curl -X POST http://nexus-ocp-workshop.apps."${CLUSTER_GUID}".example.opentlc.com/service/rest/v1/script/anonymous/run -H 'accept: application/json' -H 'Content-Type: text/plain'

echo "*** Anonymous read access configured for Nexus. ***"

oc logout


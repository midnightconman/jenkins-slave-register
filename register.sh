#!/bin/bash

set +x

#$POST_USER - env must be set 
#$POST_KEY - env must be set 
#$MASTER - env must be set 
#$CREDENTIALS_ID - env must be set 
#$SLAVE_IP - env must be set
#$SLAVE_EXECUTORS - env must be set

SLAVE_LABELS="docker docker-${HOSTNAME} docker-latest"
SLAVE_NAME="docker-${HOSTNAME}"
JENKINS_HOME="${JENKINS_HOME:-/var/jenkins}"

function post_to_master () {

  if [ "$1" == "true" ]
  then
    RESPONSE=' -w "%{http_code}"'
  else
    RESPONSE=""
  fi

  curl -L -s -S ${RESPONSE} -X POST \
    --data-binary "${DATA}" \
    --user "${POST_USER}:${POST_KEY}" \
    "http://${MASTER}/scriptText/"

}

DATA="script=
for ( slave in hudson.model.Hudson.instance.slaves ) {
  if ( '${SLAVE_NAME}' == slave.name ) {
    println( 'true' ) 
  }
}
"

echo -e "\n## Checking if slave (${SLAVE_NAME}) already exists on master (${MASTER}) ##"

SLAVE_EXISTS=$( post_to_master "false" )

if [ "${SLAVE_EXISTS}" == "true" ]
then

REMOVE_NODE="
for ( slave in hudson.model.Hudson.instance.slaves ) {
  if ( '${SLAVE_NAME}' == slave.name ) {
    jenkins.model.Jenkins.instance.removeNode(slave) 
  }
}
"

fi

DATA="script=
import jenkins.model.*
import hudson.model.*
import hudson.slaves.*
import hudson.plugins.sshslaves.SSHLauncher

sshLauncher = new SSHLauncher(
                  '${SLAVE_IP}',
                  ${SLAVE_PORT},
                  '${CREDENTIALS_ID}',
                  '',
                  '',
                  '',
                  '',
                  0,
                  5,
                  5
)

${REMOVE_NODE}

Jenkins.instance.addNode( 
                   new DumbSlave(
                         '${SLAVE_NAME}',
                         '',
                         '${JENKINS_HOME}',
                         '${SLAVE_EXECUTORS}',
                         Node.Mode.EXCLUSIVE,
                         '${SLAVE_LABELS}',
                         sshLauncher,
                         new RetentionStrategy.Always(),
                         new LinkedList() 
                         )
)
"

if [ "${SLAVE_EXISTS}" == "true" ]
then

  echo -e "\n## Updating slave (${SLAVE_NAME}) on master (${MASTER}) ##"
  echo -n "Response Status Code: "
  post_to_master "true"
  echo -e "\n## Update Complete ##\n"

else

  echo -e "\n## Adding slave (${SLAVE_NAME}) to master (${MASTER}) ##"
  echo -n "Response Status Code: "
  post_to_master "true"
  echo -e "\n## Additon Complete ##\n"

fi

#!/bin/bash

set +x

#$POST_USER - env must be set 
#$POST_KEY - env must be set 
#$MASTERS - env must be set
#$CREDENTIALS_ID - env must be set 
#$SLAVE_IP - env must be set

ACTION=${1:-deregister}
SLAVE_LABELS="${SLAVE_LABELS:-docker docker-${HOSTNAME} docker-latest}"
SLAVE_NAME="${SLAVE_NAME:-docker-${HOSTNAME}}"
SLAVE_EXECUTORS=${SLAVE_EXECUTORS:-2}
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

function add_or_remove () {

  if [ "$1" == 'add' ]
  then

    ADD_NODE="
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

  else

    ADD_NODE=''

  fi
}

function build_data () {

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

    ${ADD_NODE}
  "

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

if [ "$1" == "register" ]
then

  for MASTER in ${MASTERS}
  do
    add_or_remove add
    build_data

    echo -e "\n## Registering slave (${SLAVE_NAME}) with master (${MASTER}) ##"
    echo -n "Response Status Code: "
    post_to_master "true"
    echo -e "\n## Registration Complete ##\n"
  done

else

  for MASTER in ${MASTERS}
  do
    add_or_remove remove
    build_data

    echo -e "\n## De-Registering slave (${SLAVE_NAME}) with master (${MASTER}) ##"
    echo -n "Response Status Code: "
    post_to_master "true"
    echo -e "\n## De-Registrataion Complete ##\n"
  done

fi

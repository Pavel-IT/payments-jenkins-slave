#!/bin/bash

#
# Jenkins Swarm Client
#
# chkconfig: 2345 89 9
# description: {{ service_name }}

source /etc/rc.d/init.d/functions

[ -f /etc/jenkins-swarm ] && . /etc/jenkins-swarm

####
#### The following options can be overridden in /etc/jenkins/swarm-client
####

# The user to run swarm-client as
USER=${USER:="{{ user }}"}

# The location that the pid file should be written to
PIDFILE=${PIDFILE:="/var/run/jenkins/{{ service_name }}.pid"}

# The location that the lock file should be written to
LOCKFILE=${LOCKFILE:="/var/lock/subsys/{{ service_name }}"}

# The location that the log file should be written to
LOGFILE=${LOGFILE:="/var/log/jenkins/{{ service_name }}.log"}

# The location of the swarm-client jar file
JAR=${JAR:="/var/lib/jenkins/swarm-client-{{ jenkins_swarm_version }}.jar"}

# The arguments to pass to the JVM.  Most useful for specifying heap sizes.
JVM_ARGS=""

# The master Jenkins server to connect to
MASTER_URL=${MASTER_URL:="https://jenkins.bcn.magento.com"}

# The username to use when connecting to the master
USERNAME=${USERNAME:=""}

# The password to use when connecting to the master
PASSWORD=${PASSWORD:=""}

# The password to use when connecting to the master
PASSWORD_ENV_VAR=${PASSWORD_ENV_VAR:=""}

# The name of this slave
NAME=${NAME:="$(hostname)"}

# The number of executors to run, by default one per core
NUM_EXECUTORS=${NUM_EXECUTORS:="$(echo "$(/usr/bin/nproc) * 2" | bc)"}

# The labels to associate with each executor (space separated)
LABELS=${LABELS:=""}

# Enable/Disable swarm random name
DISABLE_RANDOM_NAME=${DISABLE_RANDOM_NAME:=""}

# Workspace folder for slaves
FSROOT=${FSROOT:="/home/{{ user }}"}

# Slave mode: normal or exclusive
MODE=${MODE:="exclusive"}

#Deletes any existing slave with the same name
FORCE_JOIN=${FORCE_JOIN:=true}

# The return value from invoking the script
RETVAL=0

start() {
  echo -n $"Starting Jenkins Swarm Client... "

  # Must be in /var/lib/jenkins for the swarm client to run properly
  local cmd="cd /var/lib/jenkins;"

  cmd="${cmd} java ${JVM_ARGS} "
  cmd="${cmd} -jar '${JAR}'"
  cmd="${cmd} -master '${MASTER_URL}'"

  if [[ -n "${USERNAME}" ]]; then
    cmd="${cmd} -username '${USERNAME}'"
  fi

  if [[ -n "${PASSWORD}" ]]; then
    cmd="${cmd} -password '${PASSWORD}'"
  fi

  if [[ -n "${PASSWORD_ENV_VAR}" ]]; then
    REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
    SWARM_PASS=$(/usr/local/bin/aws ssm get-parameters --region ${REGION} --name ${PASSWORD_ENV_VAR} --with-decryption --query "Parameters[0].Value")
    export ${PASSWORD_ENV_VAR}=`echo ${SWARM_PASS} | sed -e 's/^"//' -e 's/"$//'`
    cmd="${cmd} -passwordEnvVariable ${PASSWORD_ENV_VAR}"
  fi

  cmd="${cmd} -name '${NAME}'"

  if [[ -n "${LABELS}" ]]; then
    cmd="${cmd} -labels '${LABELS}'"
  fi

  if [[ -n "${FSROOT}" ]]; then
    cmd="${cmd} -fsroot '${FSROOT}'"
  fi

  if [[ -n "${MODE}" ]]; then
    cmd="${cmd} -mode '${MODE}'"
  fi

  if [[ "${DISABLE_RANDOM_NAME}" = true ]]; then
    cmd="${cmd} -disableClientsUniqueId"
  fi

  if [[ "${FORCE_JOIN}" = true ]]; then
    cmd="${cmd} -deleteExistingClients"
  fi

  cmd="${cmd} -executors '${NUM_EXECUTORS}'"
  cmd="${cmd} >> '${LOGFILE}' 2>&1 </dev/null &"

  daemon --user "{{ user }}" --check "swarm-client" --pidfile "${PIDFILE}" "${cmd}"

  local pid=$(ps -ef | grep "${JAR}" | grep -v grep | awk '{print $2}')
  [ -n ${pid} ] && echo ${pid} > "${PIDFILE}"
  RETVAL=$?
  [ $RETVAL -eq 0 ] && touch $LOCKFILE

  echo
}

stop() {
  echo -n $"Stopping Jenkins Swarm Client... "
  killproc -p $PIDFILE "swarm-client"
  RETVAL=$?
  echo
  [ $RETVAL -eq 0 ] && rm -f $LOCKFILE
}

restart() {
  stop
  start
}

checkstatus() {
  status -p "$PIDFILE" "swarm-client"
  RETVAL=$?
}

condrestart() {
  [ -e "$LOCKFILE" ] && restart || :
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    checkstatus
    ;;
  restart)
    restart
    ;;
  condrestart)
    condrestart
    ;;
  *)
    echo $"Usage: $0 {start|stop|status|restart|condrestart}"
    exit 1
esac

exit $RETVAL

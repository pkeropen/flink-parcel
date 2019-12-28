#!/bin/bash

# Flink Master.
USAGE="Usage: flink-master.sh (start|stop)"

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. "$bin"/config.sh

if [ ! -z "${FLINK_JM_HEAP_MB}" ] && [ "${FLINK_JM_HEAP}" == 0 ]; then
    echo "used deprecated key \`${KEY_JOBM_MEM_MB}\`, please replace with key \`${KEY_JOBM_MEM_SIZE}\`"
else
    flink_jm_heap_bytes=$(parseBytes ${FLINK_JM_HEAP})
    FLINK_JM_HEAP_MB=$(getMebiBytes ${flink_jm_heap_bytes})
fi

if [[ ! ${FLINK_JM_HEAP_MB} =~ $IS_NUMBER ]] || [[ "${FLINK_JM_HEAP_MB}" -lt "0" ]]; then
    echo "[ERROR] Configured JobManager memory size is not a valid value. Please set '${KEY_JOBM_MEM_SIZE}' in ${FLINK_CONF_FILE}."
    exit 1
fi

if [ "${FLINK_JM_HEAP_MB}" -gt "0" ]; then
    export JVM_ARGS="$JVM_ARGS -Xms"$FLINK_JM_HEAP_MB"m -Xmx"$FLINK_JM_HEAP_MB"m"
fi

# Add JobManager-specific JVM options
export FLINK_ENV_JAVA_OPTS="${FLINK_ENV_JAVA_OPTS} ${FLINK_ENV_JAVA_OPTS_JM}"

# Startup parameters
ARGS=("--configDir" "${FLINK_CONF_DIR}" "--executionMode" "cluster" "--host" "${FLINK_MASTER_HOST}" "--webui-port" "${FLINK_WEB_UI_PORT}")
echo "FLINK_MASTER_HOST: $FLINK_MASTER_HOST"
echo "FLINK_WEB_UI_PORT: $FLINK_WEB_UI_PORT"
echo "FLINK_LOG_DIR: ${FLINK_LOG_DIR}"
echo "MASTER_ARGS: ${ARGS[@]}"

CLASS_TO_RUN=org.apache.flink.runtime.entrypoint.StandaloneSessionClusterEntrypoint
FLINK_TM_CLASSPATH=`constructFlinkClassPath`
FLINK_LOG_PREFIX="${FLINK_LOG_DIR}/flink-master"

log="${FLINK_LOG_PREFIX}.log"
out="${FLINK_LOG_PREFIX}.out"

log_setting=("-Dlog.file=${log}" "-Dlog4j.configuration=file:${FLINK_CONF_DIR}/log4j.properties" "-Dlogback.configurationFile=file:${FLINK_CONF_DIR}/logback.xml")

JAVA_VERSION=$(${JAVA_RUN} -version 2>&1 | sed 's/.*version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')

# Only set JVM 8 arguments if we have correctly extracted the version
if [[ ${JAVA_VERSION} =~ ${IS_NUMBER} ]]; then
    if [ "$JAVA_VERSION" -lt 18 ]; then
        JVM_ARGS="$JVM_ARGS -XX:MaxPermSize=256m"
    fi
fi

MY_PID=$(ps -ef | grep "$CLASS_TO_RUN" | grep -v grep | awk '{print $2}')
if [ "${MY_PID}" = "" ];then
	# Rotate log files
	rotateLogFilesWithPrefix "$FLINK_LOG_DIR" "$FLINK_LOG_PREFIX"
	# Evaluate user options for local variable expansion
	FLINK_ENV_JAVA_OPTS=$(eval echo ${FLINK_ENV_JAVA_OPTS})
	CLASS_PATH=`manglePathList "$FLINK_TM_CLASSPATH:$(hadoop classpath)"`
	CLASS_PATH=$(echo "${CLASS_PATH}" | sed "s#"$FLINK_HOME"/lib/slf4j-log4j12-1.7.7.jar:##g")
	echo "Starting $DAEMON daemon (pid: $!) on host $HOSTNAME."
	exec $JAVA_RUN $JVM_ARGS ${FLINK_ENV_JAVA_OPTS} "${log_setting[@]}" -classpath "${CLASS_PATH}" ${CLASS_TO_RUN} "${ARGS[@]}" > "$out" 2>&1
else
	echo "$DAEMON daemon (pid: $MY_PID) is running on host $HOSTNAME."
fi

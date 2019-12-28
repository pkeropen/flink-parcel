#!/bin/bash

#Flink Worker.
USAGE="Usage: flink-worker.sh (start|stop)"

OPERATION=$1

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

. "$bin"/config.sh

# if memory allocation mode is lazy and no other JVM options are set,
# set the 'Concurrent Mark Sweep GC'
if [[ $FLINK_TM_MEM_PRE_ALLOCATE == "false" ]] && [ -z "${FLINK_ENV_JAVA_OPTS}" ] && [ -z "${FLINK_ENV_JAVA_OPTS_TM}" ]; then
    export JVM_ARGS="$JVM_ARGS -XX:+UseG1GC"
fi

if [ ! -z "${FLINK_TM_HEAP_MB}" ] && [ "${FLINK_TM_HEAP}" == 0 ]; then
        echo "used deprecated key \`${KEY_TASKM_MEM_MB}\`, please replace with key \`${KEY_TASKM_MEM_SIZE}\`"
else
        flink_tm_heap_bytes=$(parseBytes ${FLINK_TM_HEAP})
        FLINK_TM_HEAP_MB=$(getMebiBytes ${flink_tm_heap_bytes})
fi

if [[ ! ${FLINK_TM_HEAP_MB} =~ ${IS_NUMBER} ]] || [[ "${FLINK_TM_HEAP_MB}" -lt "0" ]]; then
    echo "[ERROR] Configured TaskManager JVM heap size is not a number. Please set '${KEY_TASKM_MEM_SIZE}' in ${FLINK_CONF_FILE}."
    exit 1
fi

if [ "${FLINK_TM_HEAP_MB}" -gt "0" ]; then

    TM_HEAP_SIZE=$(calculateTaskManagerHeapSizeMB)
    # Long.MAX_VALUE in TB: This is an upper bound, much less direct memory will be used
    TM_MAX_OFFHEAP_SIZE="8388607T"

    export JVM_ARGS="${JVM_ARGS} -Xms${TM_HEAP_SIZE}M -Xmx${TM_HEAP_SIZE}M -XX:MaxDirectMemorySize=${TM_MAX_OFFHEAP_SIZE}"

fi

# Add TaskManager-specific JVM options
export FLINK_ENV_JAVA_OPTS="${FLINK_ENV_JAVA_OPTS} ${FLINK_ENV_JAVA_OPTS_TM}"

# Startup parameters
ARGS=("--configDir" "${FLINK_CONF_DIR}")
echo "FLINK_LOG_DIR: ${FLINK_LOG_DIR}"
echo "MASTER_ARGS: ${ARGS[@]}"

CLASS_TO_RUN=org.apache.flink.runtime.taskexecutor.TaskManagerRunner
FLINK_TM_CLASSPATH=`constructFlinkClassPath`
FLINK_LOG_PREFIX="${FLINK_LOG_DIR}/flink-worker"

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


#!/bin/bash

bin=`dirname "$0"`
bin=`cd "$bin"; pwd`

# get Flink config
. "$bin"/config.sh

JVM_ARGS="$JVM_ARGS -Xmx512m"
CLASS_TO_RUN=org.apache.flink.yarn.cli.FlinkYarnSessionCli

log=$FLINK_LOG_DIR/flink-yarn.log
out=$FLINK_LOG_DIR/flink-yarn.out
log_setting="-Dlog.file="$log" -Dlog4j.configuration=file:"$FLINK_CONF_DIR"/log4j-yarn-session.properties -Dlogback.configurationFile=file:"$FLINK_CONF_DIR"/logback-yarn.xml"

# Rotate log files
rotateLogFilesWithPrefix "$FLINK_LOG_DIR" "$FLINK_LOG_PREFIX"
CLASS_PATH=`manglePathList $(constructFlinkClassPath):$INTERNAL_HADOOP_CLASSPATHS`
#CLASS_PATH=`manglePathList $(constructFlinkClassPath):$(hadoop classpath)`
#CLASS_PATH=$(echo "${CLASS_PATH}" | sed "s#"$FLINK_HOME"/lib/slf4j-log4j12-1.7.7.jar:##g")
exec $JAVA_RUN $JVM_ARGS -classpath "$CLASS_PATH" $log_setting ${CLASS_TO_RUN} -j "$FLINK_LIB_DIR"/flink-dist*.jar "$@" > "$out" 2>&1



#!/bin/bash
# For better debugging

set -x

USAGE="Usage: control.sh (start|stop)"

OPERATION=$1

case $OPERATION in
    (start)
	NODE_HOST=`hostname -f`
	#Determine if the directory exists
        
        #modified by pc

	#TEMP_PATH=$CMF_VAR/../cloudera/parcels
	#if [ ! -d "$TEMP_PATH" ];then
	#	TEMP_PATH=$CMF_VAR/../../cloudera/parcels
	#fi

	#PARCELS_DIR=`cd $TEMP_PATH; pwd`
	#FLINK_HOME=$PARCELS_DIR/FLINK-1.6.0-hadoop_2.6-scala_2.11/lib/flink
	if [ ! -d "/opt/cloudera/parcels/FLINK" ]; then
 		ln -sv /opt/cloudera/parcels/FLINK-* /opt/cloudera/parcels/FLINK
	fi
	FLINK_HOME=/opt/cloudera/parcels/FLINK/lib/flink
	
	#Determine if the configuration file directory exists
	FLINK_CONF_DIR=$CONF_DIR/flink-conf
	if [ ! -d "$FLINK_CONF_DIR" ];then
		mkdir $FLINK_CONF_DIR
	else
		rm -rf $FLINK_CONF_DIR/*
	fi
	cp $FLINK_HOME/conf/* $FLINK_CONF_DIR/
	sed -i 's#=#: #g' $CONF_DIR/flink-conf.properties
	HIGH_MODE=`cat $CONF_DIR/flink-conf.properties | grep "high-availability:"`
		
	#Determine if the variable HIGH_MODE is empty
	if [ "$HIGH_MODE" = "" ]; then
		echo "high-availability: zookeeper" >> $CONF_DIR/flink-conf.properties	
		HIGH_MODE=`cat $CONF_DIR/flink-conf.properties | grep "high-availability:"`
		echo "HIGH_MODE: $HIGH_MODE"
	fi
	HIGH_ZK_QUORUM=`cat $CONF_DIR/flink-conf.properties | grep "high-availability.zookeeper.quorum:"`
		
	#Determine if the variable HIGH_ZK_QUORUM is empty
	if [ "$HIGH_ZK_QUORUM" = "" ]; then
		echo "high-availability.zookeeper.quorum: "$ZK_QUORUM >> $CONF_DIR/flink-conf.properties	
		HIGH_ZK_QUORUM=`cat $CONF_DIR/flink-conf.properties | grep "high-availability.zookeeper.quorum:"`
		echo "HIGH_ZK_QUORUM: $HIGH_ZK_QUORUM"
	fi
	cp $CONF_DIR/flink-conf.properties $FLINK_CONF_DIR/flink-conf.yaml
	HADOOP_CONF_DIR=$CONF_DIR/yarn-conf
	export FLINK_HOME FLINK_CONF_DIR HADOOP_CONF_DIR
        echo "CONF_DIR:" $CONF_DIR
        echo "HADOOP_CONF_DIR:" $HADOOP_CONF_DIR
	echo ""
	echo "Date: `date`"
	echo "Host: $NODE_HOST"
	echo "NODE_TYPE: $NODE_TYPE"
	echo "ZK_QUORUM: $ZK_QUORUM"
	echo "FLINK_HOME: $FLINK_HOME"
	echo "FLINK_CONF_DIR: $FLINK_CONF_DIR"
	echo ""
        if [ "$FLINK_STREAMING_MODE" = "true" ]; then
		exec $FLINK_HOME/bin/flink-yarn.sh --container $FLINK_TASK_MANAGERS --streaming
	else
		exec $FLINK_HOME/bin/flink-yarn.sh --container $FLINK_TASK_MANAGERS
	fi
    ;;
	
    (stop)
	YARN_CONFIG_FILE=/tmp/.yarn-properties-$FLINK_RUN_AS_USER
	if [ -r "$YARN_CONFIG_FILE" ]; then
		YARN_APP_ID=`cat $YARN_CONFIG_FILE | grep applicationID | awk -F "=" '{print $2}'`
		if [ "$YARN_APP_ID" != "" ]; then
			echo "kill flink yarn application $YARN_APP_ID ."
			yarn application -kill $YARN_APP_ID
		fi
	fi
	CLASS_TO_RUN=org.apache.flink.yarn.cli.FlinkYarnSessionCli
	FLINK_YARN_PID=$(ps -ef | grep $CLASS_TO_RUN | grep -v grep | awk '{print $2}')
	if [ "$FLINK_YARN_PID" != "" ]; then
		echo "kill flink yarn client $FLINK_YARN_PID ."
		kill $FLINK_YARN_PID
	fi
    ;;
	
    (*)
        echo "Unknown daemon '${OPERATION}'. $USAGE."
        exit 1
    ;;
esac
	

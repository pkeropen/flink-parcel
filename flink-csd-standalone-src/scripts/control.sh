#!/bin/bash
# For better debugging
USAGE="Usage: control.sh ((master|worker) (start|stop))"

NODE_TYPE=$1
NODE_HOST=`hostname -f`


#Determine if the directory exists
TEMP_PATH=$CMF_VAR/../cloudera/parcels
if [ ! -d "$TEMP_PATH" ];then
	TEMP_PATH=$CMF_VAR/../../cloudera/parcels
fi

#PARCELS_DIR=`cd $TEMP_PATH; pwd`
if [ ! -d "/opt/cloudera/parcels/FLINK" ]; then
       ln -sv /opt/cloudera/parcels/FLINK-* /opt/cloudera/parcels/FLINK
fi

FLINK_HOME=/opt/cloudera/parcels/FLINK/lib/flink
#FLINK_HOME=$PARCELS_DIR/FLINK-1.8.0-BIN-SCALA_2.11/lib/flink
#Determine if the configuration file directory exists
FLINK_CONF_DIR=$CONF_DIR/flink-conf
if [ ! -d "$FLINK_CONF_DIR" ];then
	mkdir $FLINK_CONF_DIR
else
	 rm -rf $FLINK_CONF_DIR/*
fi
cp $FLINK_HOME/conf/* $FLINK_CONF_DIR/
sed -i 's#=#: #g' $CONF_DIR/flink-conf.properties

if [ "$NODE_TYPE" = "master" ]; then
	#Determine if the variable RPC_ADDRESS is empty
	if [ "$RPC_ADDRESS" = "" ]; then
		echo "jobmanager.rpc.address: $FLINK_MASTER_HOST" >> $CONF_DIR/flink-conf.properties   
		RPC_ADDRESS=`cat $CONF_DIR/flink-conf.properties | grep "jobmanager.rpc.address:"`
		echo "RPC_ADDRESS: $RPC_ADDRESS"
	fi
fi
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
HADOOP_CONF_DIR=$CONF_DIR/hadoop-conf
export FLINK_HOME FLINK_CONF_DIR HADOOP_CONF_DIR
echo ""

echo "Date: `date`"

echo "Host: $NODE_HOST"

echo "NODE_TYPE: $NODE_TYPE"

echo "ZK_QUORUM: $ZK_QUORUM"

echo "FLINK_HOME: $FLINK_HOME"

echo "FLINK_CONF_DIR: $FLINK_CONF_DIR"

echo ""

exec $FLINK_HOME/bin/flink-$NODE_TYPE.sh
	

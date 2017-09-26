#!/bin/bash

# set up pegasus stuff before starting

# launch cluster
peg up cluster/ozy-spark-master.yaml
peg up cluster/ozy-spark-worker.yaml

peg fetch ozy-spark

# set up ssh and aws
peg install ozy-spark ssh
peg install ozy-spark aws

# ssh into a node manually
#ssh -i $HOME/.ssh/pamela-wu-IAM-keypair.pem ubuntu@PUBLIC_IP

# install applications
peg install ozy-spark zookeeper
peg install ozy-spark kafka
peg install ozy-spark hadoop
peg install ozy-spark spark
peg install ozy-spark cassandra

# install python packages
peg sshcmd-cluster ozy-spark "sudo apt-get update"
peg sshcmd-cluster ozy-spark "sudo pip install boto3"
peg sshcmd-cluster ozy-spark "sudo pip install kafka-python"
peg sshcmd-cluster ozy-spark "sudo pip install imageio"
peg sshcmd-cluster ozy-spark "python -c 'import imageio ; imageio.plugins.ffmpeg.download()'"
peg sshcmd-cluster ozy-spark "sudo pip install -U imageio"
peg sshcmd-cluster ozy-spark "sudo pip install py4j"
peg sshcmd-cluster ozy-spark "echo 'export PYTHONPATH=\$SPARK_HOME/python:\$PYTHONPATH' >> ./.profile"
peg sshcmd-cluster ozy-spark "sudo pip install -U pip"
peg sshcmd-cluster ozy-spark "sudo apt-get install -y libopencv-dev python-opencv"
peg sshcmd-cluster ozy-spark "sudo pip install opencv-python"

peg sshcmd-cluster ozy-spark "sudo pip install cassandra-driver"

peg sshcmd-cluster ozy-spark "sudo pip install flask"
peg sshcmd-cluster ozy-spark "sudo pip install tornado"

# configure kafka manually, see server.properties
peg ssh ozy-spark 1
sudo nano $KAFKA_HOME/config/server.properties

num.partitions=10

message.max.bytes=15728640
replica.fetch.max.bytes=15728640
max.request.size=15728640
fetch.message.max.bytes=15728640

log.retention.ms=600000
log.retention.check.interval.ms=60000

# start services
peg service ozy-spark zookeeper start
peg service ozy-spark kafka start &
peg service ozy-spark hadoop start
peg service ozy-spark spark start

# download data into raw and preprocess
mkdir -p data
python -W ignore preprocess.py

# put files into the cluster
peg sshcmd-cluster ozy-spark "mkdir -p models"
peg sshcmd-node ozy-spark 1 "mkdir -p data ; mkdir -p lib ; mkdir -p web"

for n in $(seq 1 10) ; do
peg scp from-local ozy-spark $n models/haarcascade_frontalface_default.xml ./models
peg scp from-local ozy-spark $n models/haarcascade_profileface.xml ./models
peg scp from-local ozy-spark $n models/haarcascade_fullbody.xml ./models
peg scp from-local ozy-spark $n spark_init.py ./
done

peg sshcmd-cluster ozy-spark "echo 'export PYTHONPATH=\$HOME:\$PYTHONPATH' >> ./.profile"

peg scp from-local ozy-spark 1 spark_streaming.py ./
peg scp from-local ozy-spark 1 lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar ./lib

# set up web server
peg sshcmd-node ozy-spark 1 "mkdir -p web/templates ; mkdir -p web/static"
peg scp from-local ozy-spark 1 web/app.py ./web
peg scp from-local ozy-spark 1 web/templates/index.html ./web/templates
peg scp from-local ozy-spark 1 web/static/styles.css ./web/static

# create kafka producers in nodes 2 and 3
for n in 2 3 ; do
peg sshcmd-node ozy-spark $n "mkdir -p data"
done

for n in 2 3 ; do
for video in $(ls data/*) ; do
peg scp from-local ozy-spark $n $video ./data
done
done

for n in 2 3 ; do
peg scp from-local ozy-spark $n kafka_producer.py ./
done

# in node 2
topics=(010a37d3ee6f379df747d1af66c85f4 \
002d7deeeb4269e9c1960c1a7ce8 \
010a074acb1975c4d6d6e43c1faeb8 \
016a37b6c5e6ef2ea8b9532a69076 \
0026c01d82d86fab2f966bac04ddf)

for t in ${topics[@]} ; do
python kafka_producer.py data/$t.mp4 &
done

# in node 3
topics=(00959d3ca2f937a8b711c5d24a1f2 \
01046b6946ad8cd1b46595e555c43b5 \
01616ec3a3669e67979ccf791e82ee5 \
0094dd222bdbf103b92149ca3d74c \
01629166c83b0c9fe702f67bdf50d)

for t in ${topics[@]} ; do
python kafka_producer.py data/$t.mp4 &
done

# kill all producers in cluster
peg sshcmd-cluster ozy-spark "pkill -f producer"

# submit spark
$SPARK_HOME/bin/spark-submit \
--master spark://ec2-34-235-40-98.compute-1.amazonaws.com:7077 \
--jars lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar \
--conf "spark.streaming.concurrentJobs=40" \
--conf "spark.executor.memory=3g" \
--conf "spark.executor.cores=6" \
--conf "spark.streaming.receiver.maxRate=0" \
--py-files sparkstart.py \
spark_streaming.py

# run app
python web/app.py

## KAFKA SPECIFIC COMMANDS
# kill kafka producers
pkill -f producer

# delete topic
for topic in $(ls data) ; do
/usr/local/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --delete --topic $topic
done

# clear a kafka topic
/usr/local/kafka/bin/kafka-configs.sh --zookeeper localhost:2181 --alter --entity-type topics --entity-name test-video  --add-config retention.ms=1000
/usr/local/kafka/bin/kafka-configs.sh --zookeeper localhost:2181 --alter --entity-type topics --entity-name test-video  --delete-config retention.ms






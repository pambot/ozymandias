#!/bin/bash

# set up pegasus stuff before starting

# launch cluster
peg up cluster/ozy-cluster-master.yaml
peg up cluster/ozy-cluster-worker.yaml

peg fetch ozy-cluster

# set up ssh and aws
peg install ozy-cluster ssh
peg install ozy-cluster aws

# ssh into a node manually
#ssh -i $HOME/.ssh/pamela-wu-IAM-keypair.pem ubuntu@PUBLIC_IP

# install applications
peg install ozy-cluster zookeeper
peg install ozy-cluster kafka
peg install ozy-cluster hadoop
peg install ozy-cluster spark

# install python packages
peg sshcmd-cluster ozy-cluster "sudo apt-get update"
peg sshcmd-cluster ozy-cluster "sudo apt-get -y upgrade"
peg sshcmd-cluster ozy-cluster "sudo pip install boto3"
peg sshcmd-cluster ozy-cluster "sudo pip install kafka-python"
peg sshcmd-cluster ozy-cluster "sudo pip install imageio"
peg sshcmd-cluster ozy-cluster "python -c 'import imageio ; imageio.plugins.ffmpeg.download()'"
peg sshcmd-cluster ozy-cluster "sudo pip install -U imageio"
peg sshcmd-cluster ozy-cluster "sudo pip install py4j"
peg sshcmd-cluster ozy-cluster "echo 'export PYTHONPATH=\$SPARK_HOME/python:\$PYTHONPATH' >> ./.profile"
peg sshcmd-cluster ozy-cluster "sudo pip install -U pip"
peg sshcmd-cluster ozy-cluster "sudo apt-get install -y libopencv-dev python-opencv"
peg sshcmd-cluster ozy-cluster "sudo pip install opencv-python"


peg sshcmd-cluster ozy-cluster "sudo pip install flask"

# configure kafka manually, see server.properties
peg ssh ozy-cluster 1
sudo nano $KAFKA_HOME/config/server.properties

delete.topic.enable=true

num.partitions=6

message.max.bytes=15728640
replica.fetch.max.bytes=15728640
max.request.size=15728640
fetch.message.max.bytes=15728640

log.retention.hours=1
log.retention.bytes=1073741824


# start services
peg service ozy-cluster zookeeper start
peg service ozy-cluster kafka start &
peg service ozy-cluster hadoop start
peg service ozy-cluster spark start

# download data into raw and preprocess

# put files into the cluster
peg sshcmd-cluster ozy-cluster "mkdir -p models ; mkdir -p src"
peg sshcmd-node ozy-cluster 1 "mkdir -p lib"
peg sshcmd-node ozy-cluster 2 "mkdir -p web"

for n in $(seq 1 6) ; do
peg scp from-local ozy-cluster $n models/haarcascade_frontalface_default.xml ./models
peg scp from-local ozy-cluster $n models/haarcascade_profileface.xml ./models
peg scp from-local ozy-cluster $n models/haarcascade_fullbody.xml ./models
peg scp from-local ozy-cluster $n src/sparkstart.py ./src
done

peg sshcmd-cluster ozy-cluster "echo 'export PYTHONPATH=\$HOME/src:\$PYTHONPATH' >> ./.profile"

peg scp from-local ozy-cluster 1 src/ozy_streaming.py ./src
peg scp from-local ozy-cluster 1 channels.json ./
peg scp from-local ozy-cluster 1 lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar ./lib

# set up web server
peg sshcmd-node ozy-cluster 2 "mkdir -p web/templates ; mkdir -p web/static"
peg scp from-local ozy-cluster 2 web/app.py ./web
peg scp from-local ozy-cluster 2 web/templates/index.html ./web/templates
peg scp from-local ozy-cluster 2 web/static/styles.css ./web/static

# create kafka producers in nodes 2 and 3
for n in 3 4 ; do
peg sshcmd-node ozy-cluster $n "mkdir -p data"
done

for n in 3 4 ; do
for video in $(ls data/*) ; do
peg scp from-local ozy-cluster $n $video ./data
done
done

for n in 3 4 ; do
peg scp from-local ozy-cluster $n src/ozy_producer.py ./src
done

# producer in node 3
peg ssh ozy-cluster 3

topics=(010a37d3ee6f379df747d1af66c85f4 \
002d7deeeb4269e9c1960c1a7ce8 \
010a074acb1975c4d6d6e43c1faeb8 \
016a37b6c5e6ef2ea8b9532a69076 \
0026c01d82d86fab2f966bac04ddf)

for t in ${topics[@]} ; do
python src/ozy_producer.py data/$t.mp4 &
done

# producer in node 4
peg ssh ozy-cluster 4

topics=(00959d3ca2f937a8b711c5d24a1f2 \
01046b6946ad8cd1b46595e555c43b5 \
01616ec3a3669e67979ccf791e82ee5 \
0094dd222bdbf103b92149ca3d74c \
01629166c83b0c9fe702f67bdf50d)

for t in ${topics[@]} ; do
python src/ozy_producer.py data/$t.mp4 &
done

# kill all producers in cluster
#peg sshcmd-cluster ozy-cluster "pkill -f producer"

# submit spark
$SPARK_HOME/bin/spark-submit \
--master spark://ec2-52-201-42-82.compute-1.amazonaws.com:7077 \
--jars lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar \
--conf "spark.streaming.concurrentJobs=10" \
--conf "spark.executor.memory=2g" \
--conf "spark.executor.cores=6" \
--py-files src/sparkstart.py \
src/ozy_streaming.py

# run app
peg ssh ozy-cluster 2

python web/app.py

## KAFKA SPECIFIC COMMANDS
# kill kafka producers

# delete topic
for topic in 010a37d3ee6f379df747d1af66c85f4 \
002d7deeeb4269e9c1960c1a7ce8 \
010a074acb1975c4d6d6e43c1faeb8 \
016a37b6c5e6ef2ea8b9532a69076 \
0026c01d82d86fab2f966bac04ddf \
00959d3ca2f937a8b711c5d24a1f2 \
01046b6946ad8cd1b46595e555c43b5 \
01616ec3a3669e67979ccf791e82ee5 \
0094dd222bdbf103b92149ca3d74c \
01629166c83b0c9fe702f67bdf50d ; do
/usr/local/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --delete --topic $topic
done

# clear a kafka topic
/usr/local/kafka/bin/kafka-configs.sh --zookeeper localhost:2181 --alter --entity-type topics --entity-name test-video  --add-config retention.ms=1000
/usr/local/kafka/bin/kafka-configs.sh --zookeeper localhost:2181 --alter --entity-type topics --entity-name test-video  --delete-config retention.ms






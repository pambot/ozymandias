#!/bin/bash

## FOR SETUP
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
peg sshcmd-cluster ozy-cluster "sudo pip install -U pip"

peg sshcmd-cluster ozy-cluster "sudo pip install boto3"
peg sshcmd-cluster ozy-cluster "sudo pip install kafka-python"
peg sshcmd-cluster ozy-cluster "sudo pip install imageio"
peg sshcmd-cluster ozy-cluster "python -c 'import imageio ; imageio.plugins.ffmpeg.download()'"
peg sshcmd-cluster ozy-cluster "sudo pip install -U imageio"
peg sshcmd-cluster ozy-cluster "sudo pip install py4j"
peg sshcmd-cluster ozy-cluster "echo 'export PYTHONPATH=\$SPARK_HOME/python:\$PYTHONPATH' >> ./.profile"

peg sshcmd-cluster ozy-cluster "sudo apt-get install -y libopencv-dev python-opencv"
peg sshcmd-cluster ozy-cluster "sudo pip install opencv-python"

peg sshcmd-cluster ozy-cluster "sudo pip install flask"

# configure kafka
peg sshcmd-cluster ozy-cluster "sed -i '/delete.topic.enable/c\delete.topic.enable=true' /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "sed -i '/num.partitions/c\num.partitions=6' /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "sed -i '/log.retention.hours/c\log.retention.hours=1' /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "sed -i '/log.retention.bytes/c\log.retention.bytes=1073741824' /usr/local/kafka/config/server.properties"

peg sshcmd-cluster ozy-cluster "echo message.max.bytes=15728640 >> /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "echo replica.fetch.max.bytes=15728640 >> /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "echo max.request.size=15728640 >> /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "echo fetch.message.max.bytes=15728640 >> /usr/local/kafka/config/server.properties"

# start services
peg service ozy-cluster zookeeper start
peg service ozy-cluster kafka start &
peg service ozy-cluster hadoop start
peg service ozy-cluster spark start

# download data into raw and preprocess

# put files into the cluster
peg sshcmd-cluster ozy-cluster "git clone https://github.com/pambot/ozymandias.git"
peg sshcmd-cluster ozy-cluster "mv ozymandias/* ./ ; rm -rf ozymandias"
peg sshcmd-cluster ozy-cluster "mkdir models ; mkdir data ; mkdir lib"

for n in $(seq 1 10) ; do
peg scp from-local ozy-cluster $n models/haarcascade_frontalface_default.xml ./models
peg scp from-local ozy-cluster $n models/haarcascade_profileface.xml ./models
done

peg sshcmd-cluster ozy-cluster "echo 'export PYTHONPATH=\$HOME/src:\$PYTHONPATH' >> ./.profile"

peg scp from-local ozy-cluster 1 lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar ./lib

for n in 3 4 ; do
for video in $(ls data/*) ; do
peg scp from-local ozy-cluster $n $video ./data
done
done

## FOR EDITING
: '
for n in $(seq 1 10) ; do 
peg scp from-local ozy-cluster $n src/ozy_producer.py ./src
done

peg scp from-local ozy-cluster 1 src/ozy_streaming.py ./src
peg scp from-local ozy-cluster 1 channels.json ./

peg scp from-local ozy-cluster 2 web/ozy_app.py ./web
peg scp from-local ozy-cluster 2 web/templates/index.html ./web/templates
'



#!/bin/bash

## FOR SETUP
# launch cluster
peg up cluster/ozy-cluster-master.yaml
peg up cluster/ozy-cluster-worker.yaml

ssh-agent -s
peg fetch ozy-cluster

for w in $(peg describe ozy-cluster) ; do
if [[ $w == *"ec2"* ]]; then
master=$w
break
fi
done

peg sshcmd-cluster ozy-cluster "echo export MASTER_NODE=$master >> ./.profile"

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

# python general
peg sshcmd-cluster ozy-cluster "sudo apt-get update"
peg sshcmd-cluster ozy-cluster "sudo apt-get -y upgrade"
peg sshcmd-cluster ozy-cluster "sudo shutdown -r now"
sleep 10
peg sshcmd-cluster ozy-cluster "sudo pip install -U pip"

# python producers
peg sshcmd-cluster ozy-cluster "sudo pip install kafka-python"
peg sshcmd-cluster ozy-cluster "sudo pip install imageio"
peg sshcmd-cluster ozy-cluster "python -c 'import imageio ; imageio.plugins.ffmpeg.download()'"
peg sshcmd-cluster ozy-cluster "sudo pip install -U imageio"

# python spark
peg sshcmd-cluster ozy-cluster "sudo pip install py4j"
peg sshcmd-cluster ozy-cluster "echo 'export PYTHONPATH=\$SPARK_HOME/python:\$PYTHONPATH' >> ./.profile"

# python image recognition
peg sshcmd-cluster ozy-cluster "sudo apt-get install -y libopencv-dev python-opencv"
peg sshcmd-cluster ozy-cluster "sudo pip install opencv-python"

# python web
peg sshcmd-cluster ozy-cluster "sudo pip install flask"
peg sshcmd-cluster ozy-cluster "sudo apt-get install -y nginx"
peg sshcmd-cluster ozy-cluster "sudo pip install gunicorn"
peg sshcmd-cluster ozy-cluster "sudo pip install gevent"

# configure kafka
peg sshcmd-cluster ozy-cluster "sed -i '/delete.topic.enable=/c\delete.topic.enable=true' /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "sed -i '/num.partitions=/c\num.partitions=6' /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "sed -i '/log.retention.hours=/c\log.retention.hours=1' /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "sed -i '/log.retention.bytes=/c\log.retention.bytes=10000000000' /usr/local/kafka/config/server.properties"

peg sshcmd-cluster ozy-cluster "echo message.max.bytes=15000000 >> /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "echo replica.fetch.max.bytes=15000000 >> /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "echo max.request.size=15000000 >> /usr/local/kafka/config/server.properties"
peg sshcmd-cluster ozy-cluster "echo fetch.message.max.bytes=15000000 >> /usr/local/kafka/config/server.properties"

# put files into the cluster
peg sshcmd-cluster ozy-cluster "git clone https://github.com/pambot/ozymandias.git"
peg sshcmd-cluster ozy-cluster "mv ozymandias/* ./ ; rm -rf ozymandias"
peg sshcmd-cluster ozy-cluster "mkdir -p models ; mkdir -p data ; mkdir -p lib"

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


## FOR EDITING AND WEB
: '

for n in $(seq 1 10) ; do 
peg scp from-local ozy-cluster $n src/ozy_producer.py ./src
done

peg scp from-local ozy-cluster 1 src/ozy_streaming.py ./src
peg scp from-local ozy-cluster 1 channels.json ./

peg scp from-local ozy-cluster 2 web/ozy_app.py ./web
peg scp from-local ozy-cluster 2 web/templates/topic.html ./web/templates
peg scp from-local ozy-cluster 2 web/templates/index.html ./web/templates

for video in $(ls data/*.mp4) ; do ffmpeg -i $video  -r 5 "frames/$(basename $video .mp4)-%03d.jpg" ; done

for video in $(ls data/*.mp4) ; do convert -delay 20 -loop 0 -layers Optimize "frames/$(basename $video .mp4)-*.jpg" "web/static/$(basename $video .mp4).gif" ; echo "Done $video" ; done

for gif in $(ls web/static/*.gif) ; do peg scp from-local ozy-cluster 2 $gif ./web/static ; done

'



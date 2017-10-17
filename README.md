# Ozymandias
Ozymandias is pipeline for real-time, scalable processing of image recognition algorithms that was developed as part of the Insight Data Engineering program (Fall 2017). If you have one camera feed, it makes sense to [run it off of your laptop](https://blog.miguelgrinberg.com/post/video-streaming-with-flask), but if you're a video monitoring company with potentially dozens or hundreds of feeds, you need a system for ingesting all the feeds and a centralized way of processing all the incoming images and sending them back into their original channels. Ozymandias accomplishes this by ingesting video feeds with Kafka, sending all the channels to Spark Streaming that runs an example algorithm from OpenCV, sending the result to a Kafka image firehose, and visualizing the result using Flask served with Nginx/Gunicorn (database and video archiving componenets were left out due to time constraints).

![Pipeline](https://github.com/pambot/ozymandias/blob/master/pipeline.png)

I hosted this on AWS EC2 m4.xlarge instances running Ubuntu 14.04, which were set up and configured using Insight's in-house AWS EC2 manager [Pegasus](https://github.com/InsightDataScience/pegasus). The data used to spoof live feeds was downloaded in order of appearance from the Multimedia Commons [Flickr videos](http://multimedia-commons.s3-website-us-west-2.amazonaws.com/?prefix=data/videos/mp4/) from the YFCC100M dataset (Kafka essentially just plays these videos on a loop). The following guide assumes you have a cluster set up and ready to go.

## Setup and Installation
Dependencies:
* Java 8 + OpenJDK
* Zookeeper 3.4.9
* Kafka 0.10.1.1
* Hadoop 2.7.4
* Spark 2.1.1
* OpenCV 3.1.0
* NGINX 1.4.6

Python dependencies can be found in the `requirements.txt` file (make sure you update `pip`). `imageio` requires `ffmpeg`, which can be obtained by running this after installing the Python dependencies:

    python -c 'import imageio ; imageio.plugins.ffmpeg.download()'

Add some paths to your `PYTHONPATH`:

    export PYTHONPATH=$HOME/src:$SPARK_HOME/python:$PYTHONPATH >> ./.profile

Some properties need to be modified in `$KAFKA_HOME/config/server.properties` to accomodate images. The values are not exact, but these properties are pretty important to change.

    # these need to be modified
    delete.topic.enable=true
    num.partitions=6
    log.retention.hours=1
    log.retention.bytes=1073741824
    
    # these need to be added
    message.max.bytes=15728640
    replica.fetch.max.bytes=15728640
    max.request.size=15728640
    fetch.message.max.bytes=15728640

Download the files by cloning this repositiory.

    git clone https://github.com/pambot/ozymandias.git

Make some additional directories.

    for newdir in raw data lib models ; do
    mkdir -p $newdir
    done

Since they're published already, I didn't push the models I used into this repository. To obtain them, run:

    wget -P models https://raw.githubusercontent.com/opencv/opencv/master/data/haarcascades/haarcascade_frontalface_default.xml
    wget -P models https://raw.githubusercontent.com/opencv/opencv/master/data/haarcascades/haarcascade_profileface.xml

Download `spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar` from [Maven](https://mvnrepository.com/artifact/org.apache.spark/spark-streaming-kafka-0-8-assembly_2.11/2.2.0) and place it into `lib/`.

To make your own spoof data, download some MPEG4 files from the link above into `raw/`. Then do some preprocessing to make the finished result appear in `data/`:

    python video_preprocess.py

Open up `channels.json` and fill it in with your own spoof metadata. In real life, this should definitely be on a database, but I left it as a JSON file due to time constraints.

## Running the Scripts
These commands are for running the scripts found in the `src/` directory. I'm putting them here in one place, but you may not want to run these in the same node.

    # run the kafka producers
    for t in $(seq 0 <number of channels - 1>) ; do
    python src/ozy_producer.py $t &
    done
    
    # run spark streaming
    $SPARK_HOME/bin/spark-submit \
    --master spark://<master node URL>:7077 \
    --jars lib/spark-streaming-kafka-0-8-assembly_2.11-2.2.0.jar \
    --conf "spark.streaming.concurrentJobs=20" \
    --conf "spark.executor.memory=2g" \
    --conf "spark.executor.cores=6" \
    --conf "spark.streaming.backpressure.enabled=true" \
    --py-files src/sparkstart.py \
    src/ozy_streaming.py
    
    # run the web app
    cd web
    gunicorn ozy_app:app  --bind 0.0.0.0:5000 -k gevent -w 8

## Viewing the Demo
I made a deal with Insight that I could have a larger cluster than usual if I didn't have it on all of the time, which was necessary because image processing is very compute-intensive. Thus, I'm including the site here, but I also have to include the disclaimer that it will only be active when I'm demoing. Instead, please check out my demo video!

Demo link: [Ozymandias](http://www.ozymandias.site)
Demo video: [Ozymandias](https://drive.google.com/open?id=0B0yLhQa2ZfVbOXQ3VXREZnF1cG8)

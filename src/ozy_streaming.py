import os
import json
import numpy as np
import cv2
import sparkstart
from pyspark import SparkContext, SparkConf, SparkFiles
from pyspark.streaming import StreamingContext
from pyspark.streaming.kafka import KafkaUtils
from kafka import SimpleClient, KeyedProducer


ROOT = '/home/ubuntu/'


def detect_features(color):
    # opencv is BGR and channels are weighted
    color = cv2.cvtColor(color, cv2.COLOR_RGB2BGR)
    gray = cv2.cvtColor(color, cv2.COLOR_BGR2GRAY)
    
    # run facial detection
    face_detect = []
    for cascade in sparkstart.models:
        if gray.any() and not cascade.empty():
            face_detect.append(cascade.detectMultiScale(gray, 1.1, 3))
    face_detect = [fc for fc in face_detect if isinstance(fc, np.ndarray)]
    
    # draw the bounding boxes
    if face_detect:
        faces = np.vstack(face_detect)
        for (x, y, w, h) in faces:
            color = cv2.rectangle(color, (x,y), (x+w,y+h), (0,255,255), 2)
    return color


def deserializer(m):
    return m[0], np.array(json.loads(m[1]), dtype=np.uint8)


def image_detector(m):
    matrix = detect_features(m[1])
    res, jpg = cv2.imencode('.jpg', matrix)
    return m[0], jpg.tobytes()


def message_sender(m):
    client = SimpleClient('localhost:9092')
    producer = KeyedProducer(client)
    rdds = m.collect()
    for d in rdds:
        producer.send_messages('flask', bytes.encode(str(d[0])), d[1])
    return


def main():
    conf = SparkConf()
    sc = SparkContext(appName='Ozymandias', conf=conf)
    sc.setLogLevel('WARN')
    
    with open(ROOT + 'channels.json', 'r') as f:
        channels = json.load(f)
        topics = [t['topic'] for t in channels['channels']]
    
    n_secs = 1
    ssc = StreamingContext(sc, n_secs)
    stream = KafkaUtils.createDirectStream(ssc, topics, {
                        'bootstrap.servers':'localhost:9092', 
                        'group.id':'ozy-group', 
                        'fetch.message.max.bytes':'15728640',
                        'auto.offset.reset':'largest'})
    
    stream.map(
            deserializer
        ).map(
            image_detector
        ).foreachRDD(
            message_sender)
    
    ssc.start()
    ssc.awaitTermination()


if __name__ == '__main__':
    main()



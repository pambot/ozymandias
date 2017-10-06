import sys
import os
import json
import time
import imageio
import cv2
import numpy as np
from kafka import KafkaProducer


ROOT = os.getenv('HOME') + '/'
DATA = ROOT + 'data/'


def choose_channel(n):
    with open(ROOT + 'channels.json', 'r') as f:
        channels = json.load(f)
    topic = [t['topic'] for i, t in enumerate(channels['channels']) if i==n][0]
    return str(topic)


def video_loop(video_reader, producer, topic, fps):
    """Iterate through frames and pass to the producer"""
    c = 0
    for frame in video_reader:
        if c % 3 != 0:
            continue
        producer.send(topic, key=topic, value=frame)
        # time.sleep(3/fps)
    return


def main(n):
    """Stream the video into a Kafka producer in an infinite loop"""
    
    topic = choose_channel(n)
    video_reader = imageio.get_reader(DATA + topic + '.mp4', 'ffmpeg')
    metadata = video_reader.get_meta_data()
    fps = metadata['fps']

    producer = KafkaProducer(bootstrap_servers='localhost:9092',
                             batch_size=15728640,
                             linger_ms=1000,
                             max_request_size=15728640,
                             value_serializer=lambda v: json.dumps(v.tolist()))
    
    while True:
        video_loop(video_reader, producer, topic, fps)
    

if __name__ == '__main__':
    try:
        n = int(sys.argv[1])
    except (IndexError, ValueError):
        print 'Invalid channel choice. Use case: `python ozy_producer.py 1`'
        sys.exit()
    
    main(n)



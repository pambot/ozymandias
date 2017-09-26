import sys
import os
import json
import time
import imageio
import cv2
import numpy as np
from kafka import KafkaProducer

try:
    fname = sys.argv[1]
except IndexError:
    print 'Missing file name.'
    sys.exit()


video_reader = imageio.get_reader(fname, 'ffmpeg')
metadata = video_reader.get_meta_data()
fps = metadata['fps']

producer = KafkaProducer(bootstrap_servers='localhost:9092',
                         batch_size=15728640,
                         linger_ms=1000,
                         max_request_size=15728640,
                         value_serializer=lambda v: json.dumps(v.tolist()))

def video_loop(video_reader):
    c = 0
    for frame in video_reader:
        if c % 2 != 0:
            continue
        topic = os.path.splitext(os.path.basename(fname))[0]
        producer.send(topic, key=topic, value=frame)
    return


while True:
    video_loop(video_reader)


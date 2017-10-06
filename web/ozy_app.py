import os
import json
from kafka import KafkaConsumer
from flask import Flask, Response, render_template


ROOT = os.getenv('HOME') + '/'


consumer = KafkaConsumer('flask', 
                         bootstrap_servers='localhost:9092', 
                         auto_offset_reset='latest',
                         fetch_max_bytes=15728640,
                         max_partition_fetch_bytes=15728640,
                         group_id='flask-group')

app = Flask(__name__)


def get_channels():
    """Spoofs database with a very small JSON file"""
    with open(ROOT + 'channels.json', 'r') as f:
        channels = json.load(f)
    return channels


def get_title(channels, topic):
    return [ch['title'] for ch in channels['channels'] if ch['topic']==topic][0]


def video_generator(topic):
    """Video streaming generator function."""
    for msg in consumer:
        if msg.key == topic:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + msg.value + b'\r\n')


@app.route('/video/<topic>')
def video(topic):
    """Video streaming route. Put this in the src attribute of an img tag."""
    return Response(video_generator(topic),
                    mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/<topic>')
def topic(topic):
    """Video streaming page."""
    return render_template('topic.html', topic=topic, 
                                         channels=get_channels(), 
                                         title=get_title(get_channels(), topic))


@app.route('/')
def index():
    """Home page."""
    return render_template('index.html', channels=get_channels())


if __name__ == '__main__':
    app.run(host='0.0.0.0', threaded=True)



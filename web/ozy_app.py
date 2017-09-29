import json
from kafka import KafkaConsumer
from flask import Flask, Response, render_template, request
from tornado.wsgi import WSGIContainer
from tornado.httpserver import HTTPServer
from tornado.ioloop import IOLoop


consumer = KafkaConsumer('flask', 
                         bootstrap_servers='localhost:9092', 
                         auto_offset_reset='latest',
                         fetch_max_bytes=15728640,
                         max_partition_fetch_bytes=15728640,
                         group_id='flask-group')

ROOT = '/home/ubuntu/'
app = Flask(__name__)


def video_title(topic):
    """Spoofs database with a very small JSON file"""
    with open(ROOT + 'channels.json', 'r') as f:
        channels = json.load(f)
        title = [t['title'] for t in channels['channels'] if t['topic']==topic][0]
    return title


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


@app.route('/')
def index():
    """Video streaming home page."""
    topic = request.args.get('topic')
    return render_template('index.html', topic=topic, title=video_title(topic))


if __name__ == '__main__':
    app.run(host='0.0.0.0', threaded=True)



import base64
import time
from kafka import KafkaConsumer
from flask import Flask, Response, render_template, url_for


consumer = KafkaConsumer('flask', 
                         bootstrap_servers='localhost:9092', 
                         auto_offset_reset='latest',
                         fetch_max_bytes=15728640,
                         max_partition_fetch_bytes=15728640,
                         group_id='flask-group')
#for msg in consumer: print msg

app = Flask(__name__)

"""
def image_generator(topic):
    for msg in consumer:
        if msg.key == topic:
            yield ('--' + topic +'\r\n'
                   'Content-Type: image/jpeg\r\n\r\niVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\r\n')
#unicode(base64.b64encode(msg.value))


@app.route('/<topic>')
def image_stream(topic):
    return Response(image_generator(topic),
                    mimetype='multipart/x-mixed-replace; boundary=' + topic)


@app.route('/ozymandias')
def index():
    with open('topics.txt', 'r') as f:
        topics = f.read().splitlines()
    return render_template('index.html', topics=topics)
"""

def gen():
    """Video streaming generator function."""
    for msg in consumer:
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + msg.value + b'\r\n')


@app.route('/video_feed')
def video_feed():
    """Video streaming route. Put this in the src attribute of an img tag."""
    return Response(gen(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/')
def index():
    """Video streaming home page."""
    return render_template('index.html')


if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=False)



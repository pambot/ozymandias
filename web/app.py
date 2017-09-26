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


def gen():
    """Video streaming generator function."""
    for msg in consumer:
        if msg.key == '006039642c984a788569c7fea33ef3':
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



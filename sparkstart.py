import cv2

MODEL_PATH = '/home/ubuntu/models/'

models = (
    cv2.CascadeClassifier(MODEL_PATH + 'haarcascade_frontalface_default.xml'),
    cv2.CascadeClassifier(MODEL_PATH + 'haarcascade_profileface.xml'),
)

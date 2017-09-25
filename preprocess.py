import glob
import imageio
import cv2

def square_crop(frame):
    x, y, z = frame.shape
    x1, y1 = x//2, y//2
    m1 = min(x1, y1)
    return frame[x1-m1:x1+x1, y1-m1:y1+m1, :]

def format_frames(reader, writer, new_dim=(304, 304)):
    for frame in reader:
        frame = square_crop(frame)
        frame = cv2.resize(frame, dsize=new_dim, interpolation=cv2.INTER_CUBIC)
        writer.append_data(frame)
    return

if __name__ == "__main__":
    video_files = glob.glob('raw/*.mp4')
    
    for vf in video_files:
        reader = imageio.get_reader(vf, format='ffmpeg')
        writer = imageio.get_writer(vf.replace('raw/', 'data/'), format='ffmpeg')
        
        try:
            format_frames(reader, writer)
        except RuntimeError:
            continue
        
        print('Done preprocessing {0}'.format(vf.replace('raw/', '')))




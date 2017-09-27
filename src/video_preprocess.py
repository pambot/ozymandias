import glob
import imageio
import cv2

def square_crop(frame):
    """Take the smallest dimension and make the video a square"""
    x, y, z = frame.shape
    x1, y1 = x//2, y//2
    m1 = min(x1, y1)
    return frame[x1-m1:x1+x1, y1-m1:y1+m1, :]

def format_frames(reader, writer, new_dim=(304, 304)):
    """Make all videos the same size using cubic interpolation"""
    for frame in reader:
        frame = square_crop(frame)
        frame = cv2.resize(frame, dsize=new_dim, interpolation=cv2.INTER_CUBIC)
        writer.append_data(frame)
    return


def main():
    """Preprocess all video files in `raw/` but ignore malformed videos"""
    video_files = glob.glob('raw/*.mp4')
    
    for vf in video_files:
        reader = imageio.get_reader(vf, format='ffmpeg')
        writer = imageio.get_writer(vf.replace('raw/', 'data/'), format='ffmpeg')
        try:
            format_frames(reader, writer)
        except RuntimeError:
            continue


if __name__ == "__main__":
    main()




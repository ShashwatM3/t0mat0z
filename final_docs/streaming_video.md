"""
FILE: streaming_video.md
TOPIC: Streaming Video
SUMMARY: This document provides technical details on Streaming Video.
It covers: Streaming video 1. Set your mock device to **Unfold**. 2. Click **Select video** and select any supported video. This video will be used as mock streaming video. **Note**: Android doesn’t transcode video automatically. Any video used here must be in ...
Use this file for implementing features related to this topic.
"""

Streaming video

1. Set your mock device to **Unfold**.
2. Click **Select video** and select any supported video. This video will be used as mock streaming video.

    **Note**: Android doesn’t transcode video automatically. Any video used here must be in h265 format. To transcode a video to h265, you can use [FFmpeg](https://www.ffmpeg.org/). For example:

    ```bash
    ffmpeg -hwaccel videotoolbox -i input_video.mp4 -c:v hevc_videotoolbox -c:a aac_at -tag:v hvc1 -vf "scale=540:960" output_video.mov
    ```

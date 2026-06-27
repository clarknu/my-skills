---
name: voice-to-text
version: 1.0.0
description: |
  Speech/audio file to text transcription using Alibaba Cloud NLS real-time ASR.
  Supports any audio format via automatic FFmpeg transcoding.
triggers:
  - 语音转文字
  - 语音识别
  - 转写
  - 录音识别
  - 音频转文字
  - voice to text
  - transcribe
  - ASR
---

# Voice-to-Text - Speech Transcription Skill

## When to Use

- User sends an **audio file** (MP4 / AMR / MP3 / WAV / M4A / OGG / AAC) that needs speech extraction
- User explicitly asks to transcribe/recognize audio
- NOTE: WeChat Work built-in voice messages already have server-side transcription (body.voice.content). Only use this skill for audio **files** sent as attachments.

## Usage

`ash
python "/transcribe.py" "<audio_file_path>"
`

Output: Recognized Chinese text with punctuation (stdout).

## Dependencies

- ffmpeg: installed system-wide
- Python packages: alibabacloud-nls-python-sdk requests PySocks
- Alibaba Cloud NLS: credentials embedded in transcribe.py

## Pipeline

1. FFmpeg converts any audio to 16kHz mono WAV
2. Alibaba Cloud NLS WebSocket real-time streaming transcription
3. Returns punctuated Chinese text

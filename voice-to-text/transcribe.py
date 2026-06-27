#!/usr/bin/env python3
"""Voice-to-text: transcribe any audio file using Alibaba Cloud NLS."""

import sys, os, subprocess, tempfile, time, json, threading

# Load credentials from environment variables
ACCESS_ID = os.environ.get("ALIBABA_CLOUD_ACCESS_ID", "")
ACCESS_SECRET = os.environ.get("ALIBABA_CLOUD_ACCESS_SECRET", "")
APPKEY = os.environ.get("ALIBABA_CLOUD_APPKEY", "")

if not ACCESS_ID or not ACCESS_SECRET or not APPKEY:
    print("Error: Please set environment variables ALIBABA_CLOUD_ACCESS_ID, ALIBABA_CLOUD_ACCESS_SECRET, and ALIBABA_CLOUD_APPKEY", file=sys.stderr)
    sys.exit(1)


def get_token():
    from nls import token
    return token.getToken(ACCESS_ID, ACCESS_SECRET)


def convert_to_wav(audio_path):
    """Convert any audio to 16kHz mono WAV using ffmpeg."""
    ext = os.path.splitext(audio_path)[1].lower()
    if ext == ".wav":
        return audio_path
    tmp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    wav_path = tmp_file.name
    tmp_file.close()
    cmd = [
        "ffmpeg", "-y", "-nostdin", "-i", audio_path,
        "-acodec", "pcm_s16le", "-ac", "1", "-ar", "16000", wav_path,
    ]
    subprocess.run(cmd, capture_output=True, check=True)
    return wav_path


def transcribe_file(audio_path, timeout_seconds=300):
    """Transcribe audio file and return text."""
    wav_path = convert_to_wav(audio_path)
    with open(wav_path, "rb") as f:
        audio = f.read()
    pcm = audio[44:]  # skip WAV header

    tok = get_token()
    results = []
    done = threading.Event()

    def on_start(msg, *args):
        pass

    def on_sentence_end(msg, *args):
        try:
            m = json.loads(msg)
        except Exception:
            return
        t = m.get("payload", {}).get("result", "")
        if t:
            results.append(t)

    def on_completed(msg, *args):
        done.set()

    def on_error(msg, *args):
        done.set()

    from nls import NlsSpeechTranscriber
    sr = NlsSpeechTranscriber(
        token=tok,
        appkey=APPKEY,
        on_start=on_start,
        on_sentence_end=on_sentence_end,
        on_completed=on_completed,
        on_error=on_error,
    )
    sr.start(
        aformat="pcm",
        sample_rate=16000,
        enable_intermediate_result=True,
        enable_punctuation_prediction=True,
        enable_inverse_text_normalization=True,
    )

    time.sleep(0.5)
    chunk = 3200
    for i in range(0, len(pcm), chunk):
        sr.send_audio(pcm[i : i + chunk])
        time.sleep(0.1)
    sr.stop()
    done.wait(timeout=timeout_seconds)
    sr.shutdown()
    return "".join(results)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python transcribe.py <audio_file>", file=sys.stderr)
        sys.exit(1)
    audio_file = sys.argv[1]
    if not os.path.exists(audio_file):
        print(f"File not found: {audio_file}", file=sys.stderr)
        sys.exit(1)
    text = transcribe_file(audio_file)
    print(text)

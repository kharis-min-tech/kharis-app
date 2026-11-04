"""Local English -> French sermon narration, with no per-minute service fees.

Requires FFmpeg/FFprobe, faster-whisper, Argos Translate (installed en->fr model),
and a licensed French Piper voice. Models run on the operator's computer.
"""
import argparse
import html
import json
import math
import shutil
import subprocess
import tempfile
import urllib.request
import wave
from pathlib import Path

RATE = 22050


def run(*args):
    return subprocess.check_output(args, stderr=subprocess.PIPE)


def duration(path):
    return float(run("ffprobe", "-v", "error", "-show_entries", "format=duration",
                     "-of", "default=noprint_wrappers=1:nokey=1", str(path)))


def validate_segments(segments, source_duration):
    if not segments:
        raise ValueError("No speech was transcribed. No dub was produced.")
    last_end = 0
    for segment in segments:
        start, end = segment["start"], segment["end"]
        if not (math.isfinite(start) and math.isfinite(end) and
                last_end <= start < end <= source_duration + 0.05):
            raise ValueError("Transcript segments must be ordered, non-overlapping and within the original audio.")
        if not isinstance(segment.get("translation"), str) or not segment["translation"].strip():
            raise ValueError("Every segment needs a non-empty French translation.")
        last_end = end


def timestamp(seconds):
    total = round(seconds * 1000)
    hours, remainder = divmod(total, 3600000)
    minutes, remainder = divmod(remainder, 60000)
    secs, millis = divmod(remainder, 1000)
    return f"{hours:02}:{minutes:02}:{secs:02}.{millis:03}"


def subtitles(segments):
    return "WEBVTT\n\n" + "\n\n".join(
        f"{i + 1}\n{timestamp(s['start'])} --> {timestamp(s['end'])}\n"
        + html.escape(s["translation"].replace("\n\n", "\n"))
        for i, s in enumerate(segments)
    ) + "\n"


def silence(output, frames):
    # A full sermon can contain hours of silence; never allocate it all at once.
    while frames > 0:
        chunk = min(frames, RATE * 10)
        output.writeframes(b"\0\0" * chunk)
        frames -= chunk


def synthesize(segments, voice, output_path, source_duration, max_speed):
    validate_segments(segments, source_duration)
    with tempfile.TemporaryDirectory() as temp, wave.open(str(output_path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        frame = 0
        for i, s in enumerate(segments):
            if i % 25 == 0:
                print(f"Synthesizing French segment {i + 1}/{len(segments)}…", flush=True)
            raw = Path(temp) / "speech.wav"
            fitted = Path(temp) / "fitted.wav"
            with wave.open(str(raw), "wb") as audio:
                voice.synthesize_wav(s["translation"], audio)
            slot = s["end"] - s["start"]
            raw_duration = duration(raw)
            speed = max(1, (raw_duration + 0.1) / slot) if raw_duration > slot else 1
            if speed > max_speed:
                raise ValueError(f"Segment {i + 1} needs {speed:.2f}x speed. Shorten its French translation in segments.json and rerun with --segments. No words were silently dropped.")
            run("ffmpeg", "-v", "error", "-y", "-i", str(raw), "-af",
                f"atempo={speed:.8f},apad,atrim=duration={slot:.8f}",
                "-ar", str(RATE), "-ac", "1", "-c:a", "pcm_s16le", str(fitted))
            start = round(s["start"] * RATE)
            end = round(s["end"] * RATE)
            silence(output, max(0, start - frame))
            with wave.open(str(fitted), "rb") as clip:
                data = clip.readframes(end - start)
                output.writeframes(data)
                silence(output, end - start - len(data) // 2)
            frame = end
        silence(output, max(0, round(source_duration * RATE) - frame))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="Directory containing job.json from localize.mjs prepare")
    parser.add_argument("--voice", type=Path, required=True, help="French Piper .onnx model; matching .onnx.json must be beside it")
    parser.add_argument("--input", type=Path, help="Original sermon MP3; otherwise fetch sourceAudioUrl from job.json")
    parser.add_argument("--segments", type=Path, help="Previously saved and corrected segments.json")
    parser.add_argument("--whisper-model", default="small.en")
    parser.add_argument("--max-speed", type=float, default=1.8)
    args = parser.parse_args()
    if not 1 <= args.max_speed <= 2:
        parser.error("--max-speed must be between 1 and 2")
    for executable in ["ffmpeg", "ffprobe"]:
        if not shutil.which(executable):
            parser.error(f"Install {executable} and put it on PATH first")
    if not args.voice.is_file() or not Path(str(args.voice) + ".json").is_file():
        parser.error("Download a French Piper voice and its matching .onnx.json config")
    job = json.loads((args.out / "job.json").read_text(encoding="utf-8"))
    if job.get("language") != "fr":
        parser.error("This local workflow currently supports French only")
    source = args.input or args.out / "original.mp3"
    if not args.input and not source.exists():
        if not job["sourceAudioUrl"].startswith("https://"):
            parser.error("Original recording must use HTTPS")
        request = urllib.request.Request(job["sourceAudioUrl"], headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request, timeout=60) as response, source.open("wb") as output:
            shutil.copyfileobj(response, output)
    source_duration = duration(source)
    expected = job.get("durationSeconds")
    if expected and abs(source_duration - expected) > max(3, expected * 0.01):
        parser.error("Source duration differs from the catalogue. Verify that this is the exact sermon MP3, not the whole YouTube service.")
    if args.segments:
        segments = json.loads(args.segments.read_text(encoding="utf-8"))
    else:
        from faster_whisper import WhisperModel
        import argostranslate.translate
        # Do not silently download or install language packages. The operator
        # installs en->fr once, following README.md, then this runs locally.
        languages = argostranslate.translate.get_installed_languages()
        english = next((lang for lang in languages if lang.code == "en"), None)
        french = next((lang for lang in languages if lang.code == "fr"), None)
        if not english or not french:
            parser.error("Install the Argos English-to-French model first (README.md)")
        translator = english.get_translation(french)
        print("Transcribing English and translating to French…", flush=True)
        model = WhisperModel(args.whisper_model, device="cpu", compute_type="int8")
        speech, _ = model.transcribe(str(source), language="en", vad_filter=True, beam_size=5)
        segments = []
        for s in speech:
            if s.text.strip():
                segments.append({"start": s.start, "end": min(s.end, source_duration),
                                 "text": s.text.strip(), "translation": translator.translate(s.text.strip())})
                if len(segments) % 25 == 0:
                    print(f"Translated {len(segments)} segments through {timestamp(s.end)}", flush=True)
        (args.out / "segments.json").write_text(json.dumps(segments, ensure_ascii=False, indent=2), encoding="utf-8")
    validate_segments(segments, source_duration)
    from piper import PiperVoice
    voice = PiperVoice.load(str(args.voice))
    # Temp names ensure a failed generation never replaces a prior good output.
    with tempfile.TemporaryDirectory(dir=args.out) as temp:
        wav = Path(temp) / "fr.wav"
        mp3 = Path(temp) / "fr.mp3"
        synthesize(segments, voice, wav, source_duration, args.max_speed)
        run("ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libmp3lame", "-b:a", "96k", str(mp3))
        shutil.copyfile(mp3, args.out / "fr.mp3")
    (args.out / "fr.vtt").write_text(subtitles(segments), encoding="utf-8")
    print("French narration and timed subtitles created locally. Review them before creating a published manifest.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Neural vocoder pass over IVONA output: analysis (mel spectrogram) and resynthesis with BigVGAN.

  resynth.py IN.wav [--marks IN.marks] [--smooth-frames N] [--out-dir DIR]

Writes IN.bigvgan.wav (plain analysis-resynthesis) and, with --marks, IN.smooth.wav, where the
mel frames around each unit join are blended before resynthesis. The engine's units are diphones,
so the joins lie roughly midway between consecutive phone starts; the viseme marks of
`speak --marks` (type 4, one per phone) give those starts.

The unit audio itself is kept: every frame still comes from Amy's recordings, so pronunciations
and quirks survive; what the vocoder changes is the waveform rendering (codec texture, phase
discontinuities at the joins).
"""
import argparse
import os
import sys

import numpy as np
import soundfile as sf
import torch

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "vendor", "BigVGAN"))
import bigvgan  # noqa: E402
from meldataset import get_mel_spectrogram  # noqa: E402

MODEL = "nvidia/bigvgan_v2_22khz_80band_256x"


def joins_from_marks(path, sample_rate, hop):
    """mel frame indices of the estimated unit joins: midpoints between consecutive phones"""
    starts = []
    with open(path) as f:
        for line in f:
            p = line.split()
            if len(p) >= 5 and p[0] == "4":         # viseme mark: type name start end sample
                starts.append(int(p[-1]))
    starts = sorted(set(starts))
    return [((a + b) // 2) // hop for a, b in zip(starts, starts[1:])]


def smooth_joins(mel, joins, k):
    """blends the log-mel frames within k of each join towards a straight line across the join"""
    out = mel.clone()
    t = mel.shape[-1]
    for j in joins:
        a, b = j - k - 1, j + k + 1
        if a < 0 or b >= t:
            continue
        for i in range(a + 1, b):
            w = (i - a) / (b - a)
            line = (1 - w) * mel[..., a] + w * mel[..., b]
            # keep half of the original detail: a full line would blur the phone's centre
            out[..., i] = 0.5 * mel[..., i] + 0.5 * line
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("wav")
    ap.add_argument("--marks")
    ap.add_argument("--smooth-frames", type=int, default=2)
    ap.add_argument("--out-dir")
    args = ap.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = bigvgan.BigVGAN.from_pretrained(MODEL, use_cuda_kernel=False)
    model.remove_weight_norm()
    model = model.eval().to(device)
    h = model.h

    audio, sr = sf.read(args.wav, dtype="float32")
    if sr != h.sampling_rate:
        sys.exit(f"{args.wav}: {sr} Hz, the model wants {h.sampling_rate}")
    wav = torch.from_numpy(audio).unsqueeze(0)
    mel = get_mel_spectrogram(wav, h).to(device)

    base = os.path.splitext(os.path.basename(args.wav))[0]
    out_dir = args.out_dir or os.path.dirname(os.path.abspath(args.wav))
    outputs = [("bigvgan", mel)]
    if args.marks:
        joins = joins_from_marks(args.marks, sr, h.hop_size)
        outputs.append(("smooth", smooth_joins(mel, joins, args.smooth_frames)))
        print(f"{len(joins)} joins smoothed (+-{args.smooth_frames} frames)")
    for tag, m in outputs:
        with torch.inference_mode():
            y = model(m).squeeze().cpu().numpy()
        y = np.clip(y, -1.0, 1.0)
        path = os.path.join(out_dir, f"{base}.{tag}.wav")
        sf.write(path, y, h.sampling_rate, subtype="PCM_16")
        print(path)


if __name__ == "__main__":
    main()

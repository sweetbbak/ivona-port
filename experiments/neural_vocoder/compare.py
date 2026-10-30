#!/usr/bin/env python3
"""Measures the demo's outputs and writes A/B files.

  .venv/bin/python compare.py [NN ...]          (default: every out/NN.wav)

For the engine's output and each resynthesis it prints the spectral flux (log-mel change between
frames) at the estimated unit joins and elsewhere, where seams show as a higher ratio, and the
log-mel distance to the engine's output, which shows how much the pass changed. It also writes
out/NN.ab.wav: the engine, plain BigVGAN and the smoothed version, 0.5 s apart.
"""
import glob
import json
import os
import sys

import numpy as np
import soundfile as sf
import torch

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "vendor", "BigVGAN"))
sys.path.insert(0, HERE)
from env import AttrDict  # noqa: E402
from huggingface_hub import hf_hub_download  # noqa: E402
from meldataset import get_mel_spectrogram  # noqa: E402
from resynth import MODEL, joins_from_marks  # noqa: E402


def main():
    h = AttrDict(json.load(open(hf_hub_download(MODEL, "config.json"))))
    out = os.path.join(HERE, "out")
    ids = sys.argv[1:] or sorted(os.path.basename(p)[:2] for p in glob.glob(f"{out}/[0-9][0-9].wav"))

    def mel(path):
        a, _ = sf.read(path, dtype="float32")
        return get_mel_spectrogram(torch.from_numpy(a).unsqueeze(0), h)[0].numpy(), a

    print(f"{'':4} {'version':8} {'flux at joins':>14} {'flux elsewhere':>15} {'ratio':>6} "
          f"{'mel dist. to engine':>20}")
    for n in ids:
        m0, _ = mel(f"{out}/{n}.wav")
        joins = joins_from_marks(f"{out}/{n}.marks", h.sampling_rate, h.hop_size)
        near = sorted({k for j in joins for k in (j - 1, j, j + 1) if 0 < k < m0.shape[1]})
        parts = []
        for tag in ("", ".bigvgan", ".smooth"):
            if not os.path.exists(f"{out}/{n}{tag}.wav"):
                continue
            m, a = mel(f"{out}/{n}{tag}.wav")
            t = min(m.shape[1], m0.shape[1])
            flux = np.sqrt(((m[:, 1:t] - m[:, :t - 1]) ** 2).mean(axis=0))
            mask = np.zeros(t - 1, bool)
            mask[[k - 1 for k in near if k - 1 < t - 1]] = True
            fj, fo = flux[mask].mean(), flux[~mask].mean()
            dist = np.sqrt(((m[:, :t] - m0[:, :t]) ** 2).mean())
            print(f"{n:4} {tag.strip('.') or 'engine':8} {fj:14.3f} {fo:15.3f} {fj / fo:6.2f} "
                  f"{dist:20.3f}")
            parts += [a, np.zeros(h.sampling_rate // 2, np.float32)]
        sf.write(f"{out}/{n}.ab.wav", np.concatenate(parts), h.sampling_rate, subtype="PCM_16")
    print(f"A/B files: {out}/NN.ab.wav (engine, plain BigVGAN, smoothed; 0.5 s apart)")


if __name__ == "__main__":
    main()

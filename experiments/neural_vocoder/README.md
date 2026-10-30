# Neural vocoder pass (experiment)

This is an "AI smoothing" pass over the engine's output, in the spirit of OpenUtau's neural
resamplers: analyse the audio into a mel spectrogram, optionally smooth it around the unit joins,
and render a new waveform with a neural vocoder.

- **What stays:** the engine and its unit selection. Every frame still comes from Amy's
  recordings, so pronunciations and quirks, like her "crime", survive.
- **What can change:** the waveform rendering, meaning the SILK codec texture and the seams at
  the joins.

## Run

```
experiments/neural_vocoder/setup.sh          # once: .venv with PyTorch + BigVGAN's code
experiments/neural_vocoder/demo.sh /path/to/eng.gbr.amy.1.6.101.3 ["your sentence" ...]
```

For each sentence, `out/` gets three files:

| File | What it is |
|---|---|
| `NN.wav` | the engine, unchanged |
| `NN.bigvgan.wav` | plain analysis and resynthesis |
| `NN.smooth.wav` | resynthesis with the mel frames around each unit join blended |

One file at a time: `.venv/bin/python resynth.py some.wav [--marks some.marks] [--smooth-frames N]`.

## Notes

- **The model.** NVIDIA BigVGAN v2, `nvidia/bigvgan_v2_22khz_80band_256x` (MIT licence). It is a
  universal vocoder at 22,050 Hz, Amy's own sample rate, so it needs no training and no
  resampling.
- **Downloads.** The model downloads from Hugging Face on first use and is loaded by BigVGAN's
  code with `torch.load`. `setup.sh` clones that code into `vendor/`. All of `.venv/`,
  `vendor/` and `out/` stay out of git.
- **Where the joins are.** The engine's units are diphones, which join near the middle of each
  phone. `resynth.py` estimates the joins from the viseme marks of `speak --marks` (one per
  phone). The engine knows the exact unit boundaries internally, so a precise version would add
  a mark type for them.
- **Smoothing.** Joins sit in the steady middle of phones, so the blend is gentle by default:
  ±2 frames (±23 ms) moved half-way towards a straight line across the join.
- **Pitch.** This vocoder takes only the mel spectrogram, so pitch can't be edited separately.
  An NSF vocoder, as used by OpenUtau and DiffSinger, takes an F0 contour as well, so its pitch
  steps at joins could be smoothed explicitly.
- **Going further:**
  - fine-tune the vocoder on Amy's own recordings, which `vox_en_gb_amy22i` holds and the
    engine can decode;
  - add a small mel-to-mel model trained on (engine output, recording) pairs, made by
    resynthesizing database sentences without their own units.

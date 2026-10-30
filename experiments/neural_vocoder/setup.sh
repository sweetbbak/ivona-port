#!/usr/bin/env bash
# Sets up the neural vocoder experiment: a local virtual environment (.venv) with PyTorch and
# NVIDIA's BigVGAN code (vendor/BigVGAN). The model itself (nvidia/bigvgan_v2_22khz_80band_256x,
# MIT licence, ~450 MB) is downloaded from Hugging Face on first use. Nothing outside this folder
# is changed.
set -euo pipefail
cd "$(dirname "$0")"
[ -d .venv ] || uv venv -q .venv
# PyTorch with CUDA if an NVIDIA GPU is present, else the CPU build
if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
    uv pip install -q --python .venv torch --index-url https://download.pytorch.org/whl/cu128
else
    uv pip install -q --python .venv torch --index-url https://download.pytorch.org/whl/cpu
fi
uv pip install -q --python .venv numpy scipy soundfile librosa huggingface_hub
if [ ! -d vendor/BigVGAN ]; then
    git clone -q --depth 1 https://github.com/NVIDIA/BigVGAN.git vendor/BigVGAN
fi
echo "BigVGAN at $(git -C vendor/BigVGAN rev-parse --short HEAD)"
.venv/bin/python -c "import torch; print('torch', torch.__version__, 'cuda' if torch.cuda.is_available() else 'cpu')"

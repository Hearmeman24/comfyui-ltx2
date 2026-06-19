### Created by [HearmemanAI](https://www.hearmemanai.com)

# ComfyUI + LTX-2.3 — RunPod template

One-click **ComfyUI + LTX-2.3** audio-video generation. The bundled LTX Director workflow and the full LTX-2.3 model set (incl. the IC-LoRA collection) provision on first boot; the legacy **LTX-2 19b** set + workflows stay behind one opt-in flag.

> Docker image: `comfyui-ltx-template:v7`

Models are registry-driven (`src/models_registry.json`), fetched in parallel over Hugging Face (`hf_hub_download` + `hf_xet`) and skipped if already on the network volume. ComfyUI lives in the image; `models`/`user`/`output`/`input` persist on the volume, so re-deploys are fast.

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---|---|---|
| `HF_TOKEN` | — | **Required for the gated IC-LoRAs.** A Hugging Face token from an account that has accepted each gated model's license (see below). Without it, the 11 gated LoRAs are skipped. |
| `disable_ic_loras` | `false` | `true` skips the LTX-2.3 IC-LoRA collection (13 LoRAs, ~10 GB, on by default). |
| `download_ltx2_19b` | `false` | Opt in to the legacy LTX-2 19b model set + its `legacy_19b/` workflows (T2V, I2V, canny, depth). |
| `lightweight_fp8` | `false` | **19b only** — use the FP8 19b checkpoint and rewrite the 19b workflows to match. |
| `civitai_token` | — | CivitAI API token (only needed for the `*_IDS_TO_DOWNLOAD` vars). |
| `LORAS_IDS_TO_DOWNLOAD` | — | Comma-separated CivitAI **version IDs** → `models/loras/`. |
| `SDXL_MODEL_IDS_TO_DOWNLOAD` | — | Comma-separated CivitAI **version IDs** → `models/checkpoints/`. |

---

## 🚀 Deploy

1. Set env vars (optional — defaults ship the full LTX-2.3 set).
2. **Deploy.** First boot takes ~5–30 min; models download in the background while ComfyUI starts on **port 8188** (JupyterLab on **8888**). The Director workflow is pre-loaded.

---

## 📦 Default models (LTX-2.3)

`ltx-2.3-22b-dev-fp8` → checkpoints · `gemma_3_12B_it_fp4_mixed` + `ltx-2.3_text_projection_bf16` → text_encoders · distilled rank-105 LoRA → loras/ltx2 · `LTX23_video_vae` + `LTX23_audio_vae` + `taeltx2_3` → vae · `spatial-upscaler-x2-1.1` → latent_upscale_models.

Plus the distilled `…-384-1.1` + abliterated Gemma LoRAs and the IC-LoRA collection below. Edit `src/models_registry.json` to change the set.

---

## 🔒 Gated IC-LoRAs

The LTX-2.3 IC-LoRA collection (13 LoRAs, used by [ComfyUI-LTXVideo](https://github.com/Lightricks/ComfyUI-LTXVideo)) downloads to `models/loras/` by default — set `disable_ic_loras=true` to skip. **11 are gated on Hugging Face:** set `HF_TOKEN` ([hf.co/settings/tokens](https://huggingface.co/settings/tokens)) from an account that has accepted **each** license, then restart — only the missing files are re-fetched. Without a valid token they're skipped and the boot log says so.

Each repo is `huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-<Name>`:

- **Public** (always download): [Union-Control](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control), [Motion-Track-Control](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Motion-Track-Control)
- **Gated** (accept each license): `HDR`, `LipDub`, `Instant-Shave`, `Colorization`, `Cross-Eyed`, `Day-To-Night`, `Deblur`, `Decompression`, `In-Outpainting`, `Water-Simulation`, `Ingredients`

---

## 🧩 Workflows & Nodes

- **LTX Director Example Workflow (Fixed)** — runs on the default set (from the WhatDreamsCost pack).
- Legacy `legacy_19b/` workflows ship only with `download_ltx2_19b=true`.

Nodes: ComfyUI-Manager + [ComfyUI-LTXVideo](https://github.com/Lightricks/ComfyUI-LTXVideo), WhatDreamsCost, KJNodes, RES4LYF, Impact-Pack (+ Subpack), rgthree, Easy-Use, essentials, LayerStyle (+ Advance), Detail-Daemon, UltimateSDUpscale.

---

## 🛠️ Troubleshooting

- **`IMPORT FAILED`** → Manager → *Install missing custom nodes* → *Try fix*.
- **Gated LoRAs missing** → set a valid `HF_TOKEN`, accept the licenses, restart.
- **Slow / stalled boot** → check `/workspace/comfyui_*_nohup.log`.

## 🔗 Links

[LTX-2.3](https://huggingface.co/Lightricks/LTX-2.3) · [awesome-ltx2](https://github.com/wildminder/awesome-ltx2) · [WhatDreamsCost](https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI)

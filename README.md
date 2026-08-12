### Created by [HearmemanAI](https://www.hearmemanai.com)

# ComfyUI + LTX-2.3 — RunPod template

One-click **ComfyUI + LTX-2.3** audio-video generation. The bundled LTX Director workflow and the full LTX-2.3 model set (incl. the IC-LoRA collection) provision on first boot; **LTX-2.5** and the legacy **LTX-2 19b** set each stay behind one opt-in flag.

> Docker image: `comfyui-ltx-template:v9`

Models are registry-driven (`src/models_registry.json`), fetched in parallel over Hugging Face (`hf_hub_download` + `hf_xet`) and skipped if already on the network volume. ComfyUI lives in the image; `models`/`user`/`output`/`input` persist on the volume, so re-deploys are fast.

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---|---|---|
| `HF_TOKEN` | — | **Required for the gated IC-LoRAs and for LTX-2.5.** A Hugging Face token from an account that has accepted each gated model's license (see below). Without it, the 11 gated LoRAs and the whole LTX-2.5 set are skipped. |
| `download_ltx23` | `true` | The **LTX-2.3** base set + its four workflows. Set `false` to skip them (e.g. running LTX-2.5 only). Only a literal `false` turns it off. |
| `download_ltx25` | `false` | Opt in to the **LTX-2.5** model set (~52 GB, gated — needs `HF_TOKEN`). See below. |
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

**Skipping it:** `download_ltx23=false` drops these 12 models *and* the four bundled 2.3 workflows — useful if you only want LTX-2.5. Two things stay independent of it: the IC-LoRA collection (its own `disable_ic_loras` switch — the 2.5 IC-LoRA workflows reuse the 2.3 IC-LoRAs, so they're still worth having) and anything you pull via the CivitAI vars. Turning off both `download_ltx23` and `download_ltx25` leaves you with no LTX weights at all; the boot log warns if you do.

---

## 🆕 LTX-2.5 (opt-in)

Set `download_ltx25=true` **and** a valid `HF_TOKEN` to add the [LTX-2.5](https://huggingface.co/Lightricks/LTX-2.5) set on top of LTX-2.3, along with the two bundled 2.5 workflows. It's a split, Comfy-aligned pack — ~52 GB, so budget the disk and the first-boot time.

| File | → | Size |
|---|---|---|
| `ltx-2.5-22b-distilled-transformer-comfy-int8-convrot` | `diffusion_models/` | 21.5 GB |
| `gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot` | `text_encoders/` | 15.4 GB |
| `gemma4_e2b_it_bf16` (prompt enhancer) | `text_encoders/` | 10.3 GB |
| `ltx-2.5-video-vae-bf16` (DiffVAE) + `-conv-bf16` (faster) | `vae/` | 2.9 GB |
| `ltx-2.5-audio-vae-bf16` | `vae/` | 0.4 GB |
| `ltx-2.5-latent-spatial-` + `-temporal-upscaler-x2-bf16-1.0` | `latent_upscale_models/` | 1.3 GB |
| `ltx-2.5-duration-head-bf16` | `model_patches/` | 4 MB |

The transformer and text encoder are the **`comfy-int8-convrot`** builds — ComfyUI-only quantised weights (core added `int8_convrot` support in August 2026). They're what the bundled workflows load, and they halve the download against bf16.

**`Lightricks/LTX-2.5` is gated.** Accept the license on the model page with the same account your `HF_TOKEN` comes from. Boot **fails open**: if the token is missing or the license isn't accepted, the pod logs the reason, skips the 2.5 set and comes up on LTX-2.3 anyway. Fix the token and restart — only the missing files are re-fetched.

**Workflows:** `video_ltx2_5_t2v` and `video_ltx2_5_i2v` (two-stage distilled, 8 + 4 steps, with audio) ship into the workflows menu whenever `download_ltx25=true`. ComfyUI-LTXVideo also carries eight more 2.5 examples in `custom_nodes/ComfyUI-LTXVideo/example_workflows/2.5/` — note those load the **bf16** transformer and TE, so repoint their loaders at the `comfy-int8-convrot` files this template downloads.

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
- **LTX-2.5 nodes red / models missing** → the boot log says why (no token, or license not accepted). Fix it and restart; the set is skipped, never fatal.
- **Slow / stalled boot** → check `/workspace/comfyui_*_nohup.log`.

## 🔗 Links

[LTX-2.5](https://huggingface.co/Lightricks/LTX-2.5) · [LTX-2.3](https://huggingface.co/Lightricks/LTX-2.3) · [awesome-ltx2](https://github.com/wildminder/awesome-ltx2) · [WhatDreamsCost](https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI)

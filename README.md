### Created by [HearmemanAI](https://www.hearmemanai.com)

# ComfyUI + LTX-2.3 — RunPod template

One-click deployment for **ComfyUI** with **LTX-2.3** audio-video generation, including the bundled LTX Director workflow and on-boot model provisioning. The legacy **LTX-2 (19b)** model set + workflows stay available behind a single opt-in flag.

> Docker image: `comfyui-ltx-template:v6`

---

## ✨ Features

- **LTX-2.3 out of the box** — the 8-model 2.3 set (22b dev fp8 checkpoint, Gemma text encoder + text projection, video/audio/tiny VAEs, distilled dynamic LoRA, v1.1 spatial upscaler) downloads on first boot.
- **LTX Director workflow bundled** — runs on the default set with no edits.
- **Registry-driven downloads** — every model lives in `src/models_registry.json` and is fetched in parallel over Hugging Face (`hf_hub_download` + `hf_xet`), with live progress and resume-safe skip of files already on disk.
- **Image-resident ComfyUI** — ComfyUI lives in the image; `models`, `user`, `output`, `input`, and user-added `custom_nodes` persist on the network volume, so re-deploys are fast.
- **Legacy LTX-2 19b on demand** — the full 19b set (control/camera/detailer/pose IC-LoRAs, spatial + temporal upscalers, Lotus depth, skin detailer) and its T2V / I2V / canny / depth workflows ship only when you ask for them.

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---|---|---|
| `disable_ic_loras` | `false` | Set to `true` to skip the **LTX-2.3 IC-LoRA collection** (13 LoRAs, ~10 GB). They download by default. **11 of the 13 are gated** — see [Gated IC-LoRAs](#-gated-ic-loras). |
| `HF_TOKEN` | — | Hugging Face token. Needed to download the **gated** IC-LoRAs — use a token from an account that has accepted each gated model's license. |
| `download_ltx2_19b` | `false` | Opt in to the legacy **LTX-2 19b** set — adds the 19 opt-in registry models AND copies the `legacy_19b/` workflows (T2V, I2V, canny, depth). |
| `lightweight_fp8` | `false` | **19b only.** Picks the FP8 19b checkpoint instead of full precision and rewrites the 19b workflows to match. No effect on the 2.3 set (it already ships fp8). |
| `civitai_token` | — | CivitAI API token. Required only if you use the `*_IDS_TO_DOWNLOAD` vars below. |
| `LORAS_IDS_TO_DOWNLOAD` | — | Comma-separated CivitAI **version IDs** to download into `models/loras/`. |
| `SDXL_MODEL_IDS_TO_DOWNLOAD` | — | Comma-separated CivitAI **version IDs** to download into `models/checkpoints/`. |

**Example — also pull the legacy 19b set in FP8:**
```bash
download_ltx2_19b=true
lightweight_fp8=true
```

### CivitAI token

1. Log into [CivitAI](https://civitai.com/) → **Manage Account** → **API Keys**.
2. Create a key and set it as `civitai_token`.
3. The `*_IDS_TO_DOWNLOAD` vars take **model version IDs**, not model IDs.

---

## 🚀 Deploying

1. Set your env vars (optional — defaults ship the full LTX-2.3 set).
2. Click **Deploy**.
3. Wait for setup (initial setup is **5–30 minutes** depending on network + flags). Models download in the background; ComfyUI starts immediately.
4. Future deployments from the same network volume are much faster — models persist and are skipped if already on disk.

## 🌐 Accessing ComfyUI
1. Click **Connect**
2. Open **port 8188** — the LTX Director workflow is pre-loaded.

## 📓 Accessing JupyterLab
1. Click **Connect**
2. Open **port 8888**

---

## 📦 Included Models (LTX-2.3, default)

| File | Location |
|---|---|
| `ltx-2.3-22b-dev-fp8.safetensors` | `models/checkpoints/` |
| `gemma_3_12B_it_fp4_mixed.safetensors` | `models/text_encoders/` |
| `ltx-2.3_text_projection_bf16.safetensors` | `models/text_encoders/` |
| `ltx-2.3-22b-distilled-lora-dynamic_fro09_avg_rank_105_bf16.safetensors` | `models/loras/ltx2/` |
| `LTX23_video_vae_bf16.safetensors` | `models/vae/` |
| `LTX23_audio_vae_bf16.safetensors` | `models/vae/` |
| `taeltx2_3.safetensors` | `models/vae/` |
| `ltx-2.3-spatial-upscaler-x2-1.1.safetensors` | `models/latent_upscale_models/` |

Also included by default: the distilled `…-lora-384-1.1` and the abliterated Gemma LoRA, plus the **IC-LoRA collection** below. The legacy LTX-2 19b models join the set when `download_ltx2_19b=true`. Model links are sourced from [awesome-ltx2](https://github.com/wildminder/awesome-ltx2); to add or change a model, edit `src/models_registry.json`.

---

## 🔒 Gated IC-LoRAs

The **LTX-2.3 IC-LoRA collection** (13 LoRAs, used by the [ComfyUI-LTXVideo](https://github.com/Lightricks/ComfyUI-LTXVideo) example workflows) downloads into `models/loras/` **by default**. Set `disable_ic_loras=true` to skip it.

**11 of the 13 are gated on Hugging Face** — they download only if you set `HF_TOKEN` to a token from an account that has **accepted each model's license** on its page below. Without that, the gated ones are silently skipped and the boot log prints a notice pointing here. The two **public** LoRAs always download.

**To enable the gated set:** open each page, click *Agree/Access repository*, then set `HF_TOKEN` (your token from [hf.co/settings/tokens](https://huggingface.co/settings/tokens)) and restart the pod — only the missing files are re-fetched.

Public (always download):
- [Union-Control](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control)
- [Motion-Track-Control](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Motion-Track-Control)

Gated (need `HF_TOKEN` + accepted license):
- [HDR](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-HDR)
- [LipDub](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-LipDub)
- [Instant-Shave](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Instant-Shave)
- [Colorization](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Colorization)
- [Cross-Eyed](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Cross-Eyed)
- [Day-To-Night](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Day-To-Night)
- [Deblur](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Deblur)
- [Decompression](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Decompression)
- [In-Outpainting](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-In-Outpainting)
- [Water-Simulation](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Water-Simulation)
- [Ingredients](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Ingredients)

---

## 📓 Included Workflows

- **LTX Director Example Workflow (Fixed)** — the LTX-2.3 Director flow, runs out-of-the-box on the default set (from the WhatDreamsCost node pack).
- **Legacy 19b workflows** (`legacy_19b/`: T2V, I2V, canny-to-video, depth-to-video) — copied into your workflows folder only when `download_ltx2_19b=true`.

---

## 🧩 Custom Nodes

ComfyUI-Manager plus a curated node set baked into the image, including the official **[ComfyUI-LTXVideo](https://github.com/Lightricks/ComfyUI-LTXVideo)** (LTX-Video / IC-LoRA support), **WhatDreamsCost-ComfyUI**, **KJNodes**, RES4LYF, Impact-Pack (+ Subpack), rgthree, ComfyUI-Easy-Use, ComfyUI_essentials, LayerStyle (+ Advance), Detail-Daemon, and UltimateSDUpscale.

---

## 💡 Tips

- Write detailed, chronological prompts (max ~200 words).
- The 2.3 set ships the fp8 dev checkpoint by default — `lightweight_fp8` only affects the optional 19b checkpoint.

---

## 🛠️ Troubleshooting

**Missing custom nodes** (`IMPORT FAILED`) — open the **Manager** menu → **Install missing custom nodes** → **Try fix**.

**Missing models in a 19b workflow?** — set `download_ltx2_19b=true` before deploy.

**Slow or stalled startup?** — check the boot log at `/workspace/comfyui_*_nohup.log`.

**User-supplied LoRAs** — if a workflow references a LoRA that isn't bundled, drop it into `/workspace/ComfyUI/models/loras/` or pull it via `LORAS_IDS_TO_DOWNLOAD`.

---

## 🔗 Links

- [LTX-2.3 on Hugging Face](https://huggingface.co/Lightricks/LTX-2.3)
- [awesome-ltx2 model index](https://github.com/wildminder/awesome-ltx2)
- [WhatDreamsCost-ComfyUI](https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI)

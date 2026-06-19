### Created by [HearmemanAI](https://www.hearmemanai.com)

# LTX-2.3 ComfyUI Template

One-click deployment for ComfyUI with LTX-2.3 audio-video generation and the LTX Director workflow. The legacy LTX-2 (19b) model set remains available behind an opt-in flag.

## Features

- **LTX-2.3 (default)**: `ltx-2.3-22b-dev-fp8` checkpoint + `gemma_3_12B_it_fp4_mixed` text encoder, audio/video/tiny VAEs, the distilled dynamic LoRA, text projection, and the v1.1 spatial upscaler
- **LTX Director workflow**: bundled and ready to run out-of-the-box
- **Registry-driven downloads**: models live in `src/models_registry.json` and are fetched in parallel via Hugging Face (`hf_hub_download` + `hf_xet`), with live progress and resume-safe skip of files already on disk
- **Legacy LTX-2 19b set**: control/camera LoRAs, upscalers, depth model and the 19b workflows — opt-in via `download_ltx2_19b=true`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `download_ltx2_19b` | `false` | Also download the legacy LTX-2 19b model set + workflows |
| `lightweight_fp8` | `false` | (19b only) Use the FP8 19b checkpoint and rewrite the 19b workflows to match |
| `civitai_token` | - | CivitAI API token for downloads |
| `LORAS_IDS_TO_DOWNLOAD` | - | Comma-separated CivitAI LoRA IDs |
| `SDXL_MODEL_IDS_TO_DOWNLOAD` | - | Comma-separated CivitAI checkpoint IDs |

**Example (also pull the legacy 19b set):**
```bash
download_ltx2_19b=true
lightweight_fp8=true
```

## Setup

1. **Configure** environment variables (optional — defaults ship LTX-2.3)
2. **Deploy** - Initial setup takes 5-30 minutes
3. **Access** ComfyUI at the provided URL with the Director workflow pre-loaded

## Included Models (LTX-2.3, default)

| File | Location |
|------|----------|
| `ltx-2.3-22b-dev-fp8.safetensors` | `checkpoints/` |
| `gemma_3_12B_it_fp4_mixed.safetensors` | `text_encoders/` |
| `ltx-2.3_text_projection_bf16.safetensors` | `text_encoders/` |
| `ltx-2.3-22b-distilled-lora-dynamic_fro09_avg_rank_105_bf16.safetensors` | `loras/ltx2/` |
| `LTX23_video_vae_bf16.safetensors` | `vae/` |
| `LTX23_audio_vae_bf16.safetensors` | `vae/` |
| `taeltx2_3.safetensors` | `vae/` |
| `ltx-2.3-spatial-upscaler-x2-1.1.safetensors` | `latent_upscale_models/` |

Model links are sourced from [awesome-ltx2](https://github.com/wildminder/awesome-ltx2). To add or change a model, edit `src/models_registry.json` — CI (`tools/validate_models.py`) checks every URL is reachable on each push.

## Pre-configured Workflows

- **LTX Director Example Workflow (Fixed).json** — the LTX-2.3 Director flow (default)
- `workflows/legacy_19b/` — the LTX-2 19b workflows (T2V, I2V, canny, depth), deployed only when `download_ltx2_19b=true`

## CivitAI Token

1. Log into [CivitAI](https://civitai.com/)
2. Go to **Manage Account** → **API Keys**
3. Create a new key and set it in the `civitai_token` variable

## Tips

- Write detailed chronological prompts (max 200 words)
- Models download in background—ComfyUI starts immediately

## Troubleshooting

**Slow startup?** Check `/workspace/comfyui_*_nohup.log`
**Missing models in a 19b workflow?** Set `download_ltx2_19b=true` before deploy

## Links

- [LTX-2.3 HuggingFace](https://huggingface.co/Lightricks/LTX-2.3)
- [awesome-ltx2 model index](https://github.com/wildminder/awesome-ltx2)
- [WhatDreamsCost nodes](https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI)

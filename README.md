### Created by [HearmemanAI](https://www.hearmemanai.com) 🎬

# LTX-2 ComfyUI Template

---

## Overview

This template provides a **one-click deployment** to set up **ComfyUI** with **LTX-2**, a state-of-the-art audio-video foundation model. Includes pre-configured workflows, control LoRAs, and optimized model downloads.

---

## Features

✨ **LTX-2 Model Support**
- Full precision (`ltx-2-19b-dev.safetensors`) and FP8 quantized (`ltx-2-19b-dev-fp8.safetensors`) variants
- Automatic spatial and temporal upscalers for 2x resolution enhancement
- Distilled LoRA for optimized inference

🎮 **Control LoRAs**
- **Image Control**: Canny edge detection, depth guidance, detailing, pose control
- **Camera Control**: Dolly (in/out/left/right), jib (up/down), and static movements

📊 **Additional Models**
- Lotus depth estimation for advanced depth control
- Stability VAE for improved quality
- Pre-configured workflows for text-to-video and image-to-video generation

⚡ **Lightweight FP8 Mode**
- Optional lightweight variant with reduced memory footprint
- Automatic workflow updates for seamless FP8 compatibility

---

## Getting Started

### CivitAI Token (Optional)

Downloading additional LoRAs from **CivitAI** requires an **API token**. Follow these steps:

1. Log into [CivitAI](https://civitai.com/)
2. Go to **Manage Account**
3. Scroll to **API Keys** section
4. Click **+ Add API key** and create a new key
5. Use this API key by setting it in your environment variables

---

### Configure Environment Variables

The following environment variables can be configured:

| Variable | Default | Description |
|----------|---------|-------------|
| `lightweight_fp8` | `false` | Enable FP8 quantized model variant for reduced memory usage |
| `LORAS_IDS_TO_DOWNLOAD` | (empty) | Comma-separated CivitAI LoRA IDs to download |
| `SDXL_MODEL_IDS_TO_DOWNLOAD` | (empty) | Comma-separated CivitAI model IDs to download |

**Example: Enable FP8 Lightweight Mode**
```bash
lightweight_fp8=true
```

When enabled:
- Downloads `ltx-2-19b-dev-fp8.safetensors` instead of full precision
- Automatically updates workflow JSON files to reference the FP8 variant
- Reduces VRAM requirements while maintaining quality

---

### Deploying the Template

1. **Configure Environment Variables** (optional)
   - Set `lightweight_fp8=true` for reduced memory usage
   - Add CivitAI API token if downloading additional models

2. **Deploy**
   - Click Deploy and wait for setup to complete
   - Initial setup typically takes **5-30 minutes** depending on network speed

3. **Access ComfyUI**
   - After startup, navigate to ComfyUI at the provided URL
   - Pre-configured workflows are ready to use

---

## Included Models

### Core Models
- **LTX-2 19B Dev** (full precision or FP8 quantized)
- **Gemma 3 12B** text encoder
- **Spatial & Temporal Upscalers** (2x resolution enhancement)

### Control & LoRAs
- Distilled LoRA (384 resolution)
- Canny, Depth, Pose, and Detailing Control LoRAs
- Camera Control LoRAs (Dolly and Jib movements)

### Auxiliary Models
- Lotus Depth Estimation (`lotus-depth-d-v-1-1-fp16.safetensors`)
- Stability VAE (`vae-ft-mse-840000-ema-pruned.safetensors`)
- General-purpose upscaler (ITF SkinDetail)

---

## Workflows

Pre-configured workflows are included:
- **LTX2_T2V.json** - Text-to-video generation
- **LTX2_I2V.json** - Image-to-video generation
- **LTX2_canny_to_video.json** - Canny edge-guided video generation
- **LTX2_depth_to_video.json** - Depth map-guided video generation

---

## Tips for Best Results

💡 **Performance Optimization**
- Use FP8 mode (`lightweight_fp8=true`) on GPUs with limited VRAM
- Full precision mode provides better quality on high-end GPUs
- All models download in background—ComfyUI starts immediately

📝 **Prompting for LTX-2**
- Write detailed, chronological descriptions of actions and scenes
- Include specific movements, appearances, camera angles, and environmental details
- Keep prompts within 200 words for best results
- Think like a cinematographer describing a shot list

🎬 **Control LoRAs**
- Combine multiple control LoRAs for complex scenes
- Experiment with LoRA strength for fine-tuned control
- Depth and canny controls work best with descriptive prompts

---

## Troubleshooting

**Models still downloading?**
- Check `/workspace/comfyui_*.nohup.log` for download progress
- aria2c runs in the background—be patient on first deploy

**Memory issues?**
- Enable `lightweight_fp8=true` for reduced memory footprint
- Reduce inference steps in workflows

**Workflows not updating for FP8?**
- Ensure `lightweight_fp8=true` is set before deployment
- Manually update JSON workflow files if needed (replace `ltx-2-19b-dev.safetensors` with `ltx-2-19b-dev-fp8.safetensors`)

---

## Documentation

For more information on LTX-2, visit:
- [LTX-2 GitHub Repository](https://github.com/Lightricks/LTX-2)
- [LTX-2 HuggingFace Model](https://huggingface.co/Lightricks/LTX-2)
- [LTX-2 Technical Report](https://videos.ltx.io/LTX-2/grants/LTX_2_Technical_Report_compressed.pdf)

---

**Last Updated:** January 2026
**Template Version:** 1.0

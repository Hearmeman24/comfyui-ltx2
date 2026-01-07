### Created by [HearmemanAI](https://www.hearmemanai.com)

# LTX-2 ComfyUI Template

One-click deployment for ComfyUI with LTX-2 audio-video generation, control LoRAs, and optimized workflows.

## Features

- **LTX-2 Models**: Full precision or FP8 quantized variants
- **Control LoRAs**: Canny, depth, pose, detailing, camera movements (dolly/jib)
- **Upscalers**: Spatial & temporal 2x resolution enhancement
- **Additional Models**: Lotus depth estimation, Stability VAE
- **FP8 Lightweight Mode**: Reduced memory with automatic workflow updates

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `lightweight_fp8` | `false` | Use FP8 quantized model for lower VRAM |
| `civitai_token` | - | CivitAI API token for downloads |
| `LORAS_IDS_TO_DOWNLOAD` | - | Comma-separated CivitAI LoRA IDs |
| `CHECKPOINT_IDS_TO_DOWNLOAD` | - | Comma-separated checkpoint IDs |

**Example:**
```bash
lightweight_fp8=true
civitai_token=your_token_here
LORAS_IDS_TO_DOWNLOAD=123456,789012
CHECKPOINT_IDS_TO_DOWNLOAD=111222
```

## Setup

1. **Configure** environment variables (optional)
2. **Deploy** - Initial setup takes 5-30 minutes
3. **Access** ComfyUI at provided URL with pre-configured workflows

## CivitAI Token

1. Log into [CivitAI](https://civitai.com/)
2. Go to **Manage Account** → **API Keys**
3. Create new key and use in `civitai_token` variable

## Included Models

- LTX-2 19B (full or FP8)
- Gemma 3 12B text encoder
- Distilled LoRA (384 resolution)
- Image control: Canny, depth, pose, detailing
- Camera control: Dolly (4 directions), jib (up/down), static
- Lotus depth, Stability VAE, ITF upscaler

## Pre-configured Workflows

- **LTX2_T2V.json** - Text-to-video
- **LTX2_I2V.json** - Image-to-video
- **LTX2_canny_to_video.json** - Edge-guided
- **LTX2_depth_to_video.json** - Depth-guided

## Tips

- Use `lightweight_fp8=true` on GPUs with limited VRAM
- Write detailed chronological prompts (max 200 words)
- Combine multiple control LoRAs for complex scenes
- Models download in background—ComfyUI starts immediately

## Troubleshooting

**Slow startup?** Check `/workspace/comfyui_*.nohup.log`
**Memory issues?** Enable `lightweight_fp8=true`
**FP8 workflows?** Set `lightweight_fp8=true` before deploy

## Links

- [LTX-2 GitHub](https://github.com/Lightricks/LTX-2)
- [LTX-2 HuggingFace](https://huggingface.co/Lightricks/LTX-2)

# LTX-2 video with audio, ComfyUI on RunPod

Created by HearmemanAI. Something not working, or a question about a workflow? Ask in
help-and-support on [my Discord](https://discord.gg/ZVWVhT43GW). That is the only place I do
support, and it is also where new releases are announced.

The LTX video models by Lightricks, which generate the picture and its soundtrack together. LTX 2.3
downloads on every new pod. LTX 2.5 is newer and sits behind one flag, because Lightricks asks you
to accept a license first.

## Before you deploy

Set all of this on the template before you click Deploy, not after.

Click Edit Template and open the environment variables tab. You do not have to change anything: LTX
2.3 downloads by default. The two most people change are `download_ltx25` and `HF_TOKEN`, both in
the next section.

If you want LTX 2.5 or the gated IC LoRAs, set `HF_TOKEN` to a Hugging Face token from an account
that has accepted those licenses. The section below walks through it. LTX 2.5 also adds about 52 GB
on top of the 2.3 set, so size the network volume for it.

If you want your own CivitAI LoRAs or checkpoints on the pod, set `civitai_token` and the ID
variables below. The steps are
[written up on my Discord](https://discord.com/channels/1359855405613715495/1536707221788950708),
and in
[this article](https://civitai.red/articles/12333/how-to-use-hearmemans-civitai-downloader-when-deploying-a-runpod-template).

Then deploy. The first boot takes 5 to 30 minutes depending on what you turned on. ComfyUI comes up
while the models are still downloading, so you can look around before it finishes. Later deploys on
the same network volume are much faster.

FYI: this template is built for CUDA 13.0 and above.

## Environment variables

| Variable | Default | What it does |
|---|---|---|
| `download_ltx23` | true | The LTX 2.3 set and its workflows. Only a literal false turns it off. |
| `download_ltx25` | false | The LTX 2.5 set and its two workflows. Gated, so it needs `HF_TOKEN`. |
| `disable_ic_loras` | false | Set it to true to skip the IC LoRA collection, which otherwise comes with LTX 2.3. |
| `HF_TOKEN` | empty | Your Hugging Face token. Unlocks LTX 2.5 and the gated IC LoRAs. |
| `civitai_token` | empty | Your CivitAI API token |
| `CIVITAI_LORAS` | empty | Comma-separated CivitAI version IDs. They go to `models/loras`. |
| `CIVITAI_CHECKPOINTS` | empty | Comma-separated CivitAI version IDs. They go to `models/checkpoints`. |

Only the workflows belonging to the sets you enabled are installed, so the menu shows you what your
models can actually run. Turning off both sets leaves you with no weights at all, and the boot log
tells you so.

## Your Hugging Face token

LTX 2.5 and most of the IC LoRA collection are gated on Hugging Face, meaning Lightricks wants you
to accept a license on the model page first. You only do this once per account.

1. Log in at huggingface.co and accept the license on
   [Lightricks/LTX-2.5](https://huggingface.co/Lightricks/LTX-2.5), and on each
   `Lightricks/LTX-2.3-22b-IC-LoRA-*` page you want.
2. Click your profile picture, then Access Tokens, then Create new token. Read access is enough.
3. Set `HF_TOKEN` to that token on the template, and `download_ltx25` to true if you want 2.5.

Nothing here is fatal. Without a valid token the pod logs what it skipped and boots on what it could
download. Fix the token, restart, and only the missing files are fetched.

## Once it is up

Click Connect, then open port 8188 for ComfyUI or port 8888 for JupyterLab. The boot log is at
`/workspace/comfyui.log`.

Open the Workflows tab in ComfyUI. Every workflow carries notes in the graph telling you what it
does and which settings matter, which is a better place to read than this page. The pod also writes
three notes into the top of that same list on first boot: Welcome, Adding Models, and
Troubleshooting.

[My other templates](https://docs.google.com/spreadsheets/d/1NfbfZLzE9GIAD5B_y6xjK1IdW95c14oS1JuIG9QihL8/edit)

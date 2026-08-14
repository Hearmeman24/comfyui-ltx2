## What is in this template

This template runs the LTX video models by Lightricks. It comes with
three sets of workflows:

- LTX 2.3 is the main set: text to video, image to video, the LTX
  Director storyboard workflow, motion tracking and Face ID. It
  downloads by default on every new pod.
- LTX 2.5 is the newest model, with text to video and image to video
  workflows. It is off by default because Lightricks asks you to accept
  a license first. The steps are below.

The 2.3 set also includes the IC LoRA collection: effect LoRAs for
things like HDR, colorization, deblur and day to night. Most of these
are gated the same way as LTX 2.5.

## Settings you can change

Set these in the environment variables tab. Click Edit Template before
you deploy, or edit the variables on this pod and restart it.

| Variable | Default | What it does |
|---|---|---|
| download_ltx23 | true | The LTX 2.3 set. Set to false to skip it. |
| download_ltx25 | false | Set to true to download the LTX 2.5 set. Needs HF_TOKEN. |
| download_ltx2_19b | retired | The 19b set no longer ships. Leaving it set is harmless. |
| disable_ic_loras | false | Set to true to skip the IC LoRA collection. |
| lightweight_fp8 | retired | Only ever applied to the 19b model, which is retired. |
| HF_TOKEN | empty | Your Hugging Face token. Unlocks the gated models. |

## How to unlock LTX 2.5

LTX 2.5 lives in a gated repository on Hugging Face. You only do this
once:

1. Log in at huggingface.co and accept the license at
   https://huggingface.co/Lightricks/LTX-2.5
2. Create a token: click your profile picture, then Access Tokens, then
   Create new token. Read access is enough.
3. On RunPod, set HF_TOKEN to that token and download_ltx25 to true,
   then restart the pod.

Only missing files are downloaded, so nothing you already have is
fetched again. If the license is not accepted yet, the pod still boots
on LTX 2.3, and the Troubleshooting note tells you what was skipped.

## The gated IC LoRAs

Most of the IC LoRAs are gated too. The steps are the same: accept the
license on each model's Hugging Face page, set HF_TOKEN to a token from
that same account, and restart the pod. Without a token the pod boots
fine and just skips them.

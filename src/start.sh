#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Set the network volume path
NETWORK_VOLUME="/workspace"

# Set default for lightweight_fp8 mode
lightweight_fp8="${lightweight_fp8:-false}"
if [ "$lightweight_fp8" = "true" ]; then
    echo "🔧 Lightweight FP8 mode enabled"
else
    echo "📊 Running in full precision mode"
fi

# This is in case there's any special installs or overrides that needs to occur when starting the machine before starting ComfyUI
if [ -f "/workspace/additional_params.sh" ]; then
    chmod +x /workspace/additional_params.sh
    echo "Executing additional_params.sh..."
    /workspace/additional_params.sh
else
    echo "additional_params.sh not found in /workspace. Skipping..."
fi

if ! which aria2 > /dev/null 2>&1; then
    echo "Installing aria2..."
    apt-get update && apt-get install -y aria2
else
    echo "aria2 is already installed"
fi

# Check if NETWORK_VOLUME exists; if not, use root directory instead
if [ ! -d "$NETWORK_VOLUME" ]; then
    echo "NETWORK_VOLUME directory '$NETWORK_VOLUME' does not exist. You are NOT using a network volume. Setting NETWORK_VOLUME to '/' (root directory)."
    NETWORK_VOLUME="/"
    echo "NETWORK_VOLUME directory doesn't exist. Starting JupyterLab on root directory..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/ &
else
    echo "NETWORK_VOLUME directory exists. Starting JupyterLab..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/workspace &
fi

# ComfyUI source stays in the image (ephemeral, fast local disk). Models,
# workflows, outputs, inputs, and user-added custom_nodes live on the network
# volume via extra_model_paths.yaml + symlinks. This avoids the multi-minute
# mv of /ComfyUI to MooseFS on first boot. Mirrors comfyui-wan.
COMFYUI_DIR="/ComfyUI"
PERSIST_ROOT="$NETWORK_VOLUME/ComfyUI"
WORKFLOW_DIR="$PERSIST_ROOT/user/default/workflows"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

# Model category dirs live on the volume (under PERSIST_ROOT/models).
CHECKPOINTS_DIR="$PERSIST_ROOT/models/checkpoints"
LORAS_DIR="$PERSIST_ROOT/models/loras"
TEXT_ENCODERS_DIR="$PERSIST_ROOT/models/text_encoders"
VAE_DIR="$PERSIST_ROOT/models/vae"
DIFFUSION_MODELS_DIR="$PERSIST_ROOT/models/diffusion_models"
UPSCALE_MODELS_DIR="$PERSIST_ROOT/models/upscale_models"
LATENT_UPSCALE_MODELS_DIR="$PERSIST_ROOT/models/latent_upscale_models"

mkdir -p "$PERSIST_ROOT/models" "$PERSIST_ROOT/user" \
         "$PERSIST_ROOT/output" "$PERSIST_ROOT/input" \
         "$PERSIST_ROOT/custom_nodes"

# Symlink user/output/input into /ComfyUI so ComfyUI uses its default code
# paths (passing --user-directory triggers a None-user_dir bug in
# user_manager.get_users on the current ComfyUI revision). Models +
# custom_nodes still go through extra_model_paths.yaml (below) because we want
# the *additive* behavior — image-baked custom_nodes + user additions — not a
# wholesale replacement.
if [ "$NETWORK_VOLUME" != "/" ]; then
    # First boot only: migrate baked user/ content (default templates, schema)
    # to the volume before swapping in the symlink. cp -an is no-clobber, so
    # re-runs on existing volumes are safe.
    if [ -d "$COMFYUI_DIR/user" ] && [ ! -L "$COMFYUI_DIR/user" ]; then
        cp -an "$COMFYUI_DIR/user/." "$PERSIST_ROOT/user/" 2>/dev/null || true
        rm -rf "$COMFYUI_DIR/user"
    fi
    for sub in user output input; do
        [ -L "$COMFYUI_DIR/$sub" ] || rm -rf "$COMFYUI_DIR/$sub" 2>/dev/null || true
        ln -sfn "$PERSIST_ROOT/$sub" "$COMFYUI_DIR/$sub"
    done
fi

# Pull the latest LTX Director node on every boot so the image picks up
# upstream fixes without a rebuild. Best-effort: a failed pull (offline, dirty
# tree) must never block startup. Reinstall requirements only if the pull
# actually changed something.
DIRECTOR_NODE_DIR="$CUSTOM_NODES_DIR/WhatDreamsCost-ComfyUI"
if [ -d "$DIRECTOR_NODE_DIR/.git" ]; then
    echo "Updating LTX Director node (git pull)..."
    before=$(git -C "$DIRECTOR_NODE_DIR" rev-parse HEAD 2>/dev/null)
    git -C "$DIRECTOR_NODE_DIR" pull --ff-only 2>/dev/null || echo "⚠️  LTX Director git pull failed — keeping baked version."
    after=$(git -C "$DIRECTOR_NODE_DIR" rev-parse HEAD 2>/dev/null)
    if [ "$before" != "$after" ] && [ -f "$DIRECTOR_NODE_DIR/requirements.txt" ]; then
        echo "LTX Director updated — reinstalling its requirements..."
        pip install -r "$DIRECTOR_NODE_DIR/requirements.txt" || true
    fi
fi

# Generate extra_model_paths.yaml from the live $PERSIST_ROOT so paths always
# match the actual network volume (not a baked-in /workspace assumption). Skip
# the file + flag when there's no real persistent volume — PERSIST_ROOT would
# equal COMFYUI_DIR and ComfyUI's defaults already cover those paths.
EXTRA_PATHS_FLAG=""
if [ "$NETWORK_VOLUME" != "/" ]; then
    cat > "$COMFYUI_DIR/extra_model_paths.yaml" <<EOF
network_volume:
    base_path: $PERSIST_ROOT
    checkpoints: models/checkpoints
    clip: models/clip
    clip_vision: models/clip_vision
    controlnet: models/controlnet
    diffusion_models: models/diffusion_models
    embeddings: models/embeddings
    loras: models/loras
    model_patches: models/model_patches
    style_models: models/style_models
    text_encoders: models/text_encoders
    unet: models/unet
    upscale_models: models/upscale_models
    latent_upscale_models: models/latent_upscale_models
    detection: models/detection
    vae: models/vae
    custom_nodes: custom_nodes
EOF
    EXTRA_PATHS_FLAG="--extra-model-paths-config $COMFYUI_DIR/extra_model_paths.yaml"
else
    rm -f "$COMFYUI_DIR/extra_model_paths.yaml"
fi

echo "Downloading CivitAI download script to /usr/local/bin"
git clone "https://github.com/Hearmeman24/CivitAI_Downloader.git" || { echo "Git clone failed"; exit 1; }
mv CivitAI_Downloader/download_with_aria.py "/usr/local/bin/" || { echo "Move failed"; exit 1; }
chmod +x "/usr/local/bin/download_with_aria.py" || { echo "Chmod failed"; exit 1; }
rm -rf CivitAI_Downloader  # Clean up the cloned repo

download_model() {
    local url="$1"
    local full_path="$2"

    local destination_dir=$(dirname "$full_path")
    local destination_file=$(basename "$full_path")

    mkdir -p "$destination_dir"

    # Simple corruption check: file < 10MB or .aria2 files
    if [ -f "$full_path" ]; then
        local size_bytes=$(stat -f%z "$full_path" 2>/dev/null || stat -c%s "$full_path" 2>/dev/null || echo 0)
        local size_mb=$((size_bytes / 1024 / 1024))

        if [ "$size_bytes" -lt 10485760 ]; then  # Less than 10MB
            echo "🗑️  Deleting corrupted file (${size_mb}MB < 10MB): $full_path"
            rm -f "$full_path"
        else
            echo "✅ $destination_file already exists (${size_mb}MB), skipping download."
            return 0
        fi
    fi

    # Check for and remove .aria2 control files
    if [ -f "${full_path}.aria2" ]; then
        echo "🗑️  Deleting .aria2 control file: ${full_path}.aria2"
        rm -f "${full_path}.aria2"
        rm -f "$full_path"  # Also remove any partial file
    fi

    echo "📥 Downloading $destination_file to $destination_dir..."
    aria2c -x 16 -s 16 -k 1M --continue=true -d "$destination_dir" -o "$destination_file" "$url" &

    echo "Download started in background for $destination_file"
}


# ===================== Registry-driven model provisioning =====================
# All HF models — the default LTX-2.3 set AND the opt-in legacy LTX-2 19b set —
# live in src/models_registry.json and flow through hf_download_manager (mirrors
# comfyui-wan). build_manifest.py gates the 19b entries behind download_ltx2_19b
# and picks the fp8-vs-full 19b checkpoint from lightweight_fp8 (both read from
# the environment). The manager resolves sizes, runs a 3-way hf_xet pool with
# live progress, and skips any model already present (>10 MB).
#
# Runtime scripts are copied to / by start_script.sh on every boot.

# Subtle HF_TOKEN sanity check. If a token is set but rejected by HF, the gated
# IC-LoRAs will silently 401 — warn once here rather than leaving the user to
# wonder. Unset token is fine (the end-of-boot notice covers that case).
if [ -n "$HF_TOKEN" ] && \
   ! curl -sf -H "Authorization: Bearer $HF_TOKEN" https://huggingface.co/api/whoami-v2 >/dev/null 2>&1; then
    echo "⚠️  HF_TOKEN looks invalid — gated IC-LoRAs may fail to download (see README → Gated IC-LoRAs)."
fi

# ===================== LTX-2.5 opt-in preflight =====================
# Lightricks/LTX-2.5 is gated, so the whole set needs an HF_TOKEN from an
# account that accepted its license. Probe once here instead of firing nine
# doomed 403s: on any failure we log loudly, force the flag off so
# build_manifest drops the 2.5 entries, and carry on booting on LTX-2.3.
# Never fatal — an unavailable model must not cost the customer a deploy.
LTX25_PROBE_URL="https://huggingface.co/Lightricks/LTX-2.5/resolve/main/model_patches/ltx-2.5-duration-head-bf16.safetensors"
LTX25_REQUESTED="${download_ltx25:-false}"  # what the user asked for, before any forced-off
if [ "${download_ltx25:-false}" = "true" ]; then
    if [ -z "$HF_TOKEN" ]; then
        echo "❌ download_ltx25=true but HF_TOKEN is not set — LTX-2.5 is GATED on Hugging Face."
        echo "   ➜ Skipping the LTX-2.5 set and continuing on LTX-2.3 (see README → LTX-2.5)."
        export download_ltx25=false
    elif ! curl -sfI -H "Authorization: Bearer $HF_TOKEN" "$LTX25_PROBE_URL" >/dev/null 2>&1; then
        echo "❌ LTX-2.5 is unavailable to this HF_TOKEN (license not accepted, or HF unreachable)."
        echo "   ➜ Accept the license at https://huggingface.co/Lightricks/LTX-2.5 with the same"
        echo "     account, then restart the pod — only the missing files are re-fetched."
        echo "   ➜ Skipping the LTX-2.5 set and continuing on LTX-2.3 (fail-open)."
        export download_ltx25=false
    else
        echo "✅ LTX-2.5 access confirmed — queueing the LTX-2.5 set (~52 GB, first boot is slow)."
    fi
else
    echo "⏭️  download_ltx25 not set — skipping the LTX-2.5 model set."
fi

echo "📦 Provisioning models from registry..."
HF_QUEUE_FILE="/tmp/hf_download_queue.tsv"
python3 /build_manifest.py \
    --registry /models_registry.json \
    --models-root "$PERSIST_ROOT/models" \
    --manifest "$HF_QUEUE_FILE"
# The manager self-guards (stall/deadline watchdog), but wrap in `timeout` as a
# hard backstop so a wedged download can never block the boot. Either way we
# fall through and start ComfyUI — missing models surface in the notice below.
timeout --signal=TERM 4000 python3 /hf_download_manager.py "$HF_QUEUE_FILE" \
    || echo "⚠️  Model download phase ended early (some models may be missing) — continuing boot."
echo "✅ Registry models ready"

# Non-HF legacy 19b extra: the general-purpose skin upscaler is Oracle-hosted,
# so it can't go through the HF download manager — direct aria2c, gated on the
# same flag. (Mirrors WAN's handling of its non-HF 2xLiveActionV1_SPAN model.)
if [ "${download_ltx2_19b:-false}" = "true" ]; then
    download_model "https://objectstorage.us-phoenix-1.oraclecloud.com/n/ax6ygfvpvzka/b/open-modeldb-files/o/1x-ITF-SkinDiffDetail-Lite-v1.pth" "$UPSCALE_MODELS_DIR/1x-ITF-SkinDiffDetail-Lite-v1.pth"
else
    echo "⏭️  download_ltx2_19b not set — skipping legacy LTX-2 19b extras."
fi

echo "Finished downloading registry models!"

# ===================== Face-ID: BFSNodes custom node =====================
# The Best-Face-ID LoRA needs BFSNodes' "LTX Identity Transfer" node (overlap +
# source-phase reference conditioning) — the LoRA weights alone don't preserve
# identity. The LoRA itself is provisioned via models_registry.json; only the
# node is cloned here (nodes aren't registry-managed). Cloned at boot, not baked,
# so it lands on the current image without a rebuild. Best-effort: never blocks boot.
BFS_NODE_DIR="$CUSTOM_NODES_DIR/ComfyUI-BFSNodes"
if [ ! -d "$BFS_NODE_DIR/.git" ]; then
    echo "Cloning ComfyUI-BFSNodes..."
    if git clone https://github.com/alisson-anjos/ComfyUI-BFSNodes.git "$BFS_NODE_DIR"; then
        [ -f "$BFS_NODE_DIR/requirements.txt" ] && pip install -r "$BFS_NODE_DIR/requirements.txt" || true
    else
        echo "⚠️  ComfyUI-BFSNodes clone failed — Face-ID Identity Transfer node unavailable."
    fi
else
    echo "ComfyUI-BFSNodes already present."
fi

declare -A MODEL_CATEGORIES=(
    ["$NETWORK_VOLUME/ComfyUI/models/loras"]="$LORAS_IDS_TO_DOWNLOAD"
    ["$NETWORK_VOLUME/ComfyUI/models/checkpoints"]="$SDXL_MODEL_IDS_TO_DOWNLOAD"
)

# Counter to track background jobs
download_count=0

# Ensure directories exist and schedule downloads in background
for TARGET_DIR in "${!MODEL_CATEGORIES[@]}"; do
    MODEL_IDS_STRING="${MODEL_CATEGORIES[$TARGET_DIR]}"

    # Skip when the var is unset or still the RunPod default placeholder —
    # otherwise we try to download a model literally named "replace_with_ids".
    if [[ -z "$MODEL_IDS_STRING" || "$MODEL_IDS_STRING" == "replace_with_ids" ]]; then
        echo "⏭️  No CivitAI IDs set for $TARGET_DIR — skipping."
        continue
    fi

    # IDs are set but the token is missing/placeholder: skip rather than fire a
    # doomed download with token=token_here.
    if [[ -z "$civitai_token" || "$civitai_token" == "token_here" ]]; then
        echo "⚠️  CivitAI IDs set for $TARGET_DIR but civitai_token is not configured — skipping."
        continue
    fi

    mkdir -p "$TARGET_DIR"
    IFS=',' read -ra MODEL_IDS <<< "$MODEL_IDS_STRING"

    for MODEL_ID in "${MODEL_IDS[@]}"; do
        MODEL_ID="$(echo "$MODEL_ID" | xargs)"  # trim whitespace
        [[ -z "$MODEL_ID" || "$MODEL_ID" == "replace_with_ids" ]] && continue
        sleep 6
        echo "🚀 Scheduling download: $MODEL_ID to $TARGET_DIR"
        (cd "$TARGET_DIR" && download_with_aria.py -m "$MODEL_ID") &
        ((download_count++))
    done
done

echo "📋 Scheduled $download_count downloads in background"

# Wait for all downloads to complete
echo "⏳ Waiting for downloads to complete..."
while pgrep -x "aria2c" > /dev/null; do
    echo "🔽 Downloads still in progress..."
    sleep 5  # Check every 5 seconds
done

echo "✅ All models downloaded successfully!"

echo "Checking and copying workflow..."
mkdir -p "$WORKFLOW_DIR"

# Ensure the file exists in the current directory before moving it
cd /

SOURCE_DIR="/comfyui-ltx2/workflows"

# Ensure destination directory exists
mkdir -p "$WORKFLOW_DIR"

# Loop over each file in the source directory. Top-level holds the LTX-2.3
# workflows; the legacy 19b workflows live in legacy_19b/ and are only copied
# when download_ltx2_19b=true (the loop skips subdirectories).
copy_workflow() {
    local file="$1"
    [[ -f "$file" ]] || return
    local dest_file="$WORKFLOW_DIR/$(basename "$file")"
    if [[ -e "$dest_file" ]]; then
        echo "File already exists in destination. Deleting: $file"
        rm -f "$file"
    else
        echo "Moving: $file to $WORKFLOW_DIR"
        mv "$file" "$WORKFLOW_DIR"
    fi
}

for file in "$SOURCE_DIR"/*; do
    copy_workflow "$file"
done

# Legacy 19b workflows ship only when the 19b model set was downloaded.
if [ "${download_ltx2_19b:-false}" = "true" ]; then
    for file in "$SOURCE_DIR"/legacy_19b/*; do
        copy_workflow "$file"
    done
fi

# Same for the LTX-2.5 workflows — shipping them without the 2.5 models just
# hands the customer two workflows full of red nodes. Keyed off what the user
# asked for, not the preflight's forced-off value: if the set was requested but
# the gate blocked it, the workflows still land and the boot notice explains.
if [ "$LTX25_REQUESTED" = "true" ]; then
    for file in "$SOURCE_DIR"/LTX2.5/*; do
        copy_workflow "$file"
    done
fi

# Rewrite legacy 19b workflows to the FP8 model name (19b-only; the 2.3 set
# already ships the fp8 dev checkpoint by default, so no rewrite is needed).
if [ "${download_ltx2_19b:-false}" = "true" ] && [ "$lightweight_fp8" = "true" ]; then
    echo "🔧 Updating workflow files for FP8 model..."
    for json_file in "$WORKFLOW_DIR"/*.json; do
        if [ -f "$json_file" ]; then
            sed -i 's/ltx-2-19b-dev\.safetensors/ltx-2-19b-dev-fp8.safetensors/g' "$json_file"
            echo "✅ Updated: $(basename "$json_file")"
        fi
    done
else
    echo "⏭️  Skipping workflow FP8 updates (lightweight_fp8 is false)"
fi

# Workspace as main working directory
echo "cd $NETWORK_VOLUME" >> ~/.bashrc


echo "Updating default preview method..."
CONFIG_PATH="$NETWORK_VOLUME/ComfyUI/user/default/ComfyUI-Manager"
CONFIG_FILE="$CONFIG_PATH/config.ini"

# Ensure the directory exists
mkdir -p "$CONFIG_PATH"

# Create the config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating config.ini..."
    cat <<EOL > "$CONFIG_FILE"
[default]
preview_method = auto
git_exe =
use_uv = False
channel_url = https://raw.githubusercontent.com/ltdrdata/ComfyUI-Manager/main
share_option = all
bypass_ssl = False
file_logging = True
component_policy = workflow
update_policy = stable-comfyui
windows_selector_event_loop_policy = False
model_download_by_agent = False
downgrade_blacklist =
security_level = normal
skip_migration_check = False
always_lazy_install = False
network_mode = public
db_mode = cache
EOL
else
    echo "config.ini already exists. Updating preview_method..."
    sed -i 's/^preview_method = .*/preview_method = auto/' "$CONFIG_FILE"
fi
echo "Config file setup complete!"
echo "Default preview method updated to 'auto'"

# Pin kornia 0.8.2 before launch. ComfyUI-LTXVideo requires kornia unpinned and
# imports `pad` from kornia.geometry.transform.pyramid; kornia 0.8.3 removed that
# re-export, so the node fails to import ("cannot import name 'pad'"). 0.8.2 is
# the last release that exposes it (needs only torch>=2.0.0). Done at boot so the
# fix lands without an image rebuild; pip is a no-op once 0.8.2 is installed.
if ! python3 -c "import kornia,sys; sys.exit(0 if kornia.__version__=='0.8.2' else 1)" 2>/dev/null; then
    echo "🔧 Pinning kornia==0.8.2 for ComfyUI-LTXVideo..."
    pip install "kornia==0.8.2"
fi

URL="http://127.0.0.1:8188"
echo "Starting ComfyUI"

# ComfyUI runs from the image (/ComfyUI); models/user/output/input resolve via
# the symlinks + extra_model_paths.yaml generated above.
nohup python3 "$COMFYUI_DIR/main.py" --listen --enable-cors-header '*' \
    $EXTRA_PATHS_FLAG \
    > "$NETWORK_VOLUME/comfyui_${RUNPOD_POD_ID}_nohup.log" 2>&1 &
until curl --silent --fail "$URL" --output /dev/null; do
  echo "🔄  ComfyUI Starting Up... You can view the startup logs here: $NETWORK_VOLUME/comfyui_${RUNPOD_POD_ID}_nohup.log"
  sleep 2
done
echo "🚀 ComfyUI is ready"

# Missing-model notices. Both the gated LTX-2.3 IC-LoRAs and the opt-in LTX-2.5
# set can legitimately not land (no HF_TOKEN, license not accepted) — every path
# fails open, so this notice is the only signal the customer gets. Keep the two
# groups apart: a skipped LTX-2.5 set must never read as a missing IC-LoRA.
missing_models() {  # $1 = ic | ltx25  ->  "<count>\n<name>\n<name>..."
    python3 - "$PERSIST_ROOT/models" "$1" "${REGISTRY_JSON:-/models_registry.json}" <<'PY'
import json, os, sys
root, group, registry = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    reg = json.load(open(registry))
except Exception:
    print(0); raise SystemExit


def in_group(e):
    if group == "ltx25":
        return e.get("flag") == "download_ltx25"
    return bool(e.get("gated")) and e.get("disable_flag") == "disable_ic_loras"


missing = [n for n, e in reg.items()
           if in_group(e) and not os.path.isfile(os.path.join(root, e["subdir"], n))]
print(len(missing))
for n in missing:
    print(n)
PY
}

if [ "${disable_ic_loras:-false}" != "true" ]; then
    GATED_MISSING=$(missing_models ic)
    GATED_COUNT=$(printf '%s\n' "$GATED_MISSING" | head -n1)
    if [ "${GATED_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        echo ""
        echo "⚠️  ${GATED_COUNT} gated IC-LoRA(s) were NOT downloaded:"
        printf '%s\n' "$GATED_MISSING" | tail -n +2 | sed 's/^/      - /'
        echo ""
        echo "    These LTX-2.3 IC-LoRAs are GATED on Hugging Face. To get them you must:"
        echo "      1. Open each model page and accept its license (links in README.md)."
        echo "      2. Set the HF_TOKEN env var to a token from that same account."
        echo "      3. Restart the pod — only the missing files are re-fetched."
        echo "    Full list, per-model links and details: README.md → 'Gated IC-LoRAs'."
        echo "    (Or set disable_ic_loras=true to skip the IC-LoRA set entirely.)"
        echo ""
    fi
fi

if [ "$LTX25_REQUESTED" = "true" ]; then
    LTX25_MISSING=$(missing_models ltx25)
    LTX25_COUNT=$(printf '%s\n' "$LTX25_MISSING" | head -n1)
    if [ "${LTX25_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        echo ""
        echo "⚠️  download_ltx25=true but ${LTX25_COUNT} LTX-2.5 file(s) are missing:"
        printf '%s\n' "$LTX25_MISSING" | tail -n +2 | sed 's/^/      - /'
        echo ""
        echo "    ComfyUI started anyway on the LTX-2.3 set — the LTX-2.5 workflows will"
        echo "    show red nodes until these land. Lightricks/LTX-2.5 is GATED:"
        echo "      1. Accept the license at https://huggingface.co/Lightricks/LTX-2.5"
        echo "      2. Set HF_TOKEN to a token from that same account."
        echo "      3. Restart the pod — only the missing files are re-fetched."
        echo "    Details: README.md → 'LTX-2.5'."
        echo ""
    else
        echo "✅ LTX-2.5 set complete — open video_ltx2_5_t2v / video_ltx2_5_i2v in the workflows menu."
    fi
fi

sleep infinity


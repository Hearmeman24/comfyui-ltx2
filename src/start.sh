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

# Check if NETWORK_VOLUME is /workspace and set up extra model paths (only if IS_DEV is true)
USE_EXTRA_MODEL_PATHS=false
if [ "$IS_DEV" = "true" ] && [ "$NETWORK_VOLUME" = "/workspace" ]; then
    echo "IS_DEV is true and NETWORK_VOLUME is /workspace. Setting up extra model paths..."
    
    # Create /models/diffusion_models directory
    mkdir -p /models/diffusion_models
    
    # Copy all .safetensors files from /workspace/ComfyUI/models/diffusion_models to /models/diffusion_models in background
    if [ -d "/workspace/ComfyUI/models/diffusion_models" ]; then
        echo "Copying .safetensors files from /workspace/ComfyUI/models/diffusion_models to /models/diffusion_models in background..."
        (
            find /workspace/ComfyUI/models/diffusion_models -name "*.safetensors" -type f | while read -r file; do
                filename=$(basename "$file")
                cp "$file" "/models/diffusion_models/disk_${filename}"
            done
            echo "✅ Finished copying .safetensors files to /models/diffusion_models"
        ) > /tmp/model_copy.log 2>&1 &
        USE_EXTRA_MODEL_PATHS=true
    else
        echo "⚠️  Source directory /workspace/ComfyUI/models/diffusion_models does not exist. Skipping copy."
    fi
else
    if [ "$IS_DEV" != "true" ]; then
        echo "IS_DEV is not set to true. Skipping extra model paths setup."
    elif [ "$NETWORK_VOLUME" != "/workspace" ]; then
        echo "NETWORK_VOLUME is not /workspace. Skipping extra model paths setup."
    fi
fi

COMFYUI_DIR="$NETWORK_VOLUME/ComfyUI"
WORKFLOW_DIR="$NETWORK_VOLUME/ComfyUI/user/default/workflows"
MODEL_WHITELIST_DIR="$NETWORK_VOLUME/ComfyUI/user/default/ComfyUI-Impact-Subpack/model-whitelist.txt"
DIFFUSION_MODELS_DIR="$NETWORK_VOLUME/ComfyUI/models/diffusion_models"
CHECKPOINTS_DIR="$NETWORK_VOLUME/ComfyUI/models/checkpoints"
LORAS_DIR="$NETWORK_VOLUME/ComfyUI/models/loras"
TEXT_ENCODERS_DIR="$NETWORK_VOLUME/ComfyUI/models/text_encoders"
VAE_DIR="$NETWORK_VOLUME/ComfyUI/models/vae"
UPSCALE_MODELS_DIR="$NETWORK_VOLUME/ComfyUI/models/upscale_models"
LATENT_UPSCALE_MODELS_DIR="$NETWORK_VOLUME/ComfyUI/models/latent_upscale_models"

if [ ! -d "$COMFYUI_DIR" ]; then
    mv /ComfyUI "$COMFYUI_DIR"
else
    echo "Directory already exists, skipping move."
fi

# Update ComfyUI to master branch and pull latest changes
echo "Updating ComfyUI repository..."
cd "$COMFYUI_DIR"
git checkout master
git pull
echo "✅ ComfyUI repository updated"

# Install ComfyUI requirements
echo "Installing ComfyUI requirements..."
/opt/venv/bin/python3 -m pip install -r "$NETWORK_VOLUME/ComfyUI/requirements.txt"
echo "✅ ComfyUI requirements installed"

# Clone ComfyUI-VAE-Utils custom node
CUSTOM_NODES_DIR="$NETWORK_VOLUME/ComfyUI/custom_nodes"
VAE_UTILS_DIR="$CUSTOM_NODES_DIR/ComfyUI-VAE-Utils"
mkdir -p "$CUSTOM_NODES_DIR"
if [ -d "$VAE_UTILS_DIR" ]; then
    echo "🗑️  Deleting existing ComfyUI-VAE-Utils directory..."
    rm -rf "$VAE_UTILS_DIR"
fi
echo "📥 Cloning ComfyUI-VAE-Utils custom node..."
cd "$CUSTOM_NODES_DIR"
git clone https://github.com/spacepxl/ComfyUI-VAE-Utils.git
echo "✅ ComfyUI-VAE-Utils cloned successfully"

# Clone ComfyUI-FSampler custom node
FSAMPLER_DIR="$CUSTOM_NODES_DIR/ComfyUI-FSampler"
if [ ! -d "$FSAMPLER_DIR" ]; then
    echo "📥 Cloning ComfyUI-FSampler custom node..."
    cd "$CUSTOM_NODES_DIR"
    git clone https://github.com/obisin/ComfyUI-FSampler.git
    echo "✅ ComfyUI-FSampler cloned successfully"
else
    echo "✅ ComfyUI-FSampler already exists, skipping clone."
fi

# Clone ComfyUI-HMNodes custom node if GITHUB_PAT is set
if [ -n "$GITHUB_PAT" ]; then
    HMNODES_DIR="$CUSTOM_NODES_DIR/ComfyUI-HMNodes"
    if [ ! -d "$HMNODES_DIR" ]; then
        echo "📥 GITHUB_PAT detected. Cloning ComfyUI-HMNodes custom node..."
        cd "$CUSTOM_NODES_DIR"
        if git clone "https://${GITHUB_PAT}@github.com/Hearmeman24/ComfyUI-HMNodes.git" 2>&1 | tee /tmp/hmnodes_clone.log; then
            echo "✅ ComfyUI-HMNodes cloned successfully"
        else
            echo "❌ Failed to clone ComfyUI-HMNodes. Error details:"
            cat /tmp/hmnodes_clone.log
        fi
    else
        echo "✅ ComfyUI-HMNodes already exists, skipping clone."
    fi
else
    echo "⏭️  GITHUB_PAT not set. Skipping ComfyUI-HMNodes clone."
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


# Download LTX-2 Main Model
if [ "$lightweight_fp8" = "true" ]; then
    download_model "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-dev-fp8.safetensors" "$CHECKPOINTS_DIR/ltx-2-19b-dev-fp8.safetensors"
else
    download_model "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-dev.safetensors" "$CHECKPOINTS_DIR/ltx-2-19b-dev.safetensors"
fi

# Download LTX-2 Text Encoder (Gemma)
download_model "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it.safetensors" "$TEXT_ENCODERS_DIR/gemma_3_12B_it.safetensors"

# Download LTX-2 Upscalers
download_model "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors" "$LATENT_UPSCALE_MODELS_DIR/ltx-2-spatial-upscaler-x2-1.0.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-temporal-upscaler-x2-1.0.safetensors" "$LATENT_UPSCALE_MODELS_DIR/ltx-2-temporal-upscaler-x2-1.0.safetensors"

# Download LTX-2 Distilled LoRA
download_model "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors" "$LORAS_DIR/ltx-2-19b-distilled-lora-384.safetensors"

# Download LTX-2 Control LoRAs - Image Control
download_model "https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Canny-Control/resolve/main/ltx-2-19b-ic-lora-canny-control.safetensors" "$LORAS_DIR/ltx-2-19b-ic-lora-canny-control.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Depth-Control/resolve/main/ltx-2-19b-ic-lora-depth-control.safetensors" "$LORAS_DIR/ltx-2-19b-ic-lora-depth-control.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Detailer/resolve/main/ltx-2-19b-ic-lora-detailer.safetensors" "$LORAS_DIR/ltx-2-19b-ic-lora-detailer.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Pose-Control/resolve/main/ltx-2-19b-ic-lora-pose-control.safetensors" "$LORAS_DIR/ltx-2-19b-ic-lora-pose-control.safetensors"

# Download LTX-2 Control LoRAs - Camera Control
download_model "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-In/resolve/main/ltx-2-19b-lora-camera-control-dolly-in.safetensors" "$LORAS_DIR/ltx-2-19b-lora-camera-control-dolly-in.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors" "$LORAS_DIR/ltx-2-19b-lora-camera-control-dolly-left.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Out/resolve/main/ltx-2-19b-lora-camera-control-dolly-out.safetensors" "$LORAS_DIR/ltx-2-19b-lora-camera-control-dolly-out.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Right/resolve/main/ltx-2-19b-lora-camera-control-dolly-right.safetensors" "$LORAS_DIR/ltx-2-19b-lora-camera-control-dolly-right.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Jib-Down/resolve/main/ltx-2-19b-lora-camera-control-jib-down.safetensors" "$LORAS_DIR/ltx-2-19b-lora-camera-control-jib-down.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Jib-Up/resolve/main/ltx-2-19b-lora-camera-control-jib-up.safetensors" "$LORAS_DIR/ltx-2-19b-lora-camera-control-jib-up.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Static/resolve/main/ltx-2-19b-lora-camera-control-static.safetensors" "$LORAS_DIR/ltx-2-19b-lora-camera-control-static.safetensors"

# Download general-purpose upscaler
download_model "https://objectstorage.us-phoenix-1.oraclecloud.com/n/ax6ygfvpvzka/b/open-modeldb-files/o/1x-ITF-SkinDiffDetail-Lite-v1.pth" "$UPSCALE_MODELS_DIR/1x-ITF-SkinDiffDetail-Lite-v1.pth"

# Download Lotus Depth Estimation Model
download_model "https://huggingface.co/Kijai/lotus-comfyui/resolve/main/lotus-depth-d-v-1-1-fp16.safetensors" "$DIFFUSION_MODELS_DIR/lotus-depth-d-v-1-1-fp16.safetensors"

# Download Stability VAE
download_model "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" "$VAE_DIR/vae-ft-mse-840000-ema-pruned.safetensors"

# Download additional models
echo "📥 Starting additional model downloads..."

if [ ! -f "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4xLSDIR.pth" ]; then
    if [ -f "/4xLSDIR.pth" ]; then
        mv "/4xLSDIR.pth" "$NETWORK_VOLUME/ComfyUI/models/upscale_models/4xLSDIR.pth"
        echo "Moved 4xLSDIR.pth to the correct location."
    else
        echo "4xLSDIR.pth not found in the root directory."
    fi
else
    echo "4xLSDIR.pth already exists. Skipping."
fi

echo "Finished downloading models!"

declare -A MODEL_CATEGORIES=(
    ["$NETWORK_VOLUME/ComfyUI/models/loras"]="$LORAS_IDS_TO_DOWNLOAD"
    ["$NETWORK_VOLUME/ComfyUI/models/checkpoints"]="$SDXL_MODEL_IDS_TO_DOWNLOAD"
)

# Counter to track background jobs
download_count=0

# Ensure directories exist and schedule downloads in background
for TARGET_DIR in "${!MODEL_CATEGORIES[@]}"; do
    mkdir -p "$TARGET_DIR"
    IFS=',' read -ra MODEL_IDS <<< "${MODEL_CATEGORIES[$TARGET_DIR]}"

    for MODEL_ID in "${MODEL_IDS[@]}"; do
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

# Loop over each file in the source directory
for file in "$SOURCE_DIR"/*; do
    # Skip if it's not a file
    [[ -f "$file" ]] || continue

    dest_file="$WORKFLOW_DIR/$(basename "$file")"

    if [[ -e "$dest_file" ]]; then
        echo "File already exists in destination. Deleting: $file"
        rm -f "$file"
    else
        echo "Moving: $file to $WORKFLOW_DIR"
        mv "$file" "$WORKFLOW_DIR"
    fi
done

# Update workflow JSON files if lightweight_fp8 is enabled
if [ "$lightweight_fp8" = "true" ]; then
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

URL="http://127.0.0.1:8188"
echo "Starting ComfyUI"

# Build ComfyUI command with optional flags
COMFYUI_CMD="python3 $NETWORK_VOLUME/ComfyUI/main.py --listen"

if [ "$USE_EXTRA_MODEL_PATHS" == "true" ]; then
  COMFYUI_CMD="$COMFYUI_CMD --extra-model-paths-config /comfyui-ltx2/src/extra_model_paths.yaml"
fi

nohup $COMFYUI_CMD > "$NETWORK_VOLUME/comfyui_${RUNPOD_POD_ID}_nohup.log" 2>&1 &
until curl --silent --fail "$URL" --output /dev/null; do
  echo "🔄  ComfyUI Starting Up... You can view the startup logs here: $NETWORK_VOLUME/comfyui_${RUNPOD_POD_ID}_nohup.log"
  sleep 2
done
echo "🚀 ComfyUI is ready"
sleep infinity


# shellcheck shell=bash
# pre_download hook for comfyui-ltx2 (CONTRACTS.md section 7).
# No shebang on purpose: this file is SOURCED, never executed.
#
# SOURCED by /comfyui-runtime/src/start.sh immediately before the provisioner,
# so `export` here reaches the provisioner's environment and the report_warn /
# report_off helpers are in scope. Sourcing rules: no `exit`, no `set -e`,
# runs on EVERY boot and must be idempotent, network probes bounded with
# curl --max-time, own errors handled here (a nonzero return only warns).
#
# Ported from the pre-migration src/start.sh:190-193 (HF_TOKEN sanity check)
# and :213-231 (LTX-2.5 gated-licence preflight). Decision #18 lives here:
# forcing download_ltx25=false BEFORE the provisioner runs means the LTX-2.5
# workflows are not copied either (the old LTX25_REQUESTED split, which still
# shipped the workflows on the ask, is retired), and report_off puts the
# unlock steps into the Troubleshooting note's "Switched off" section.

# --- HF_TOKEN sanity check -------------------------------------------------
# A token that is set but rejected by HF means every gated download will
# silently 401. Warn once here rather than leave the customer to wonder.
if [ -n "$HF_TOKEN" ] && \
   ! curl -sf --max-time 30 -H "Authorization: Bearer $HF_TOKEN" \
        https://huggingface.co/api/whoami-v2 >/dev/null 2>&1; then
    echo "⚠️  HF_TOKEN looks invalid; gated models (IC-LoRAs, LTX-2.5) may fail to download."
    report_warn "HF_TOKEN looks invalid; gated model downloads may fail"
fi

# --- gated IC-LoRAs without a token ----------------------------------------
# 11 of the 14 IC-LoRAs are HF-gated. Without a token the provisioner drops
# them (fail-open, registry `gated` semantics); this note replaces the old
# post-launch missing-model notice (pre-migration src/start.sh:513-529).
if [ -z "$HF_TOKEN" ] && [ "${disable_ic_loras:-false}" != "true" ]; then
    report_off "Gated IC-LoRAs" \
        "Most of the IC LoRA effects need a Hugging Face token. Accept the license on each model's Hugging Face page, set HF_TOKEN to a token from that account, and restart the pod. Only the missing files are downloaded."
fi

# --- LTX-2.5 opt-in preflight ----------------------------------------------
# Lightricks/LTX-2.5 is gated, so the whole set needs an HF_TOKEN from an
# account that accepted its licence. Probe once here instead of firing nine
# doomed 403s: on any failure, log loudly, force the flag off so the
# provisioner drops both the 2.5 models AND the 2.5 workflows, and carry on
# booting on LTX-2.3. Never fatal (decision #19).
LTX25_UNLOCK="Accept the license at https://huggingface.co/Lightricks/LTX-2.5, set HF_TOKEN to a token from that same account, and restart the pod. Only the missing files are downloaded."
LTX25_PROBE_URL="https://huggingface.co/Lightricks/LTX-2.5/resolve/main/model_patches/ltx-2.5-duration-head-bf16.safetensors"
# Match the provisioner's opt-in truthiness (CONTRACTS.md section 3), not
# just a bare "true": whatever enables the flag there must be preflighted here.
ltx25_req="$(printf '%s' "${download_ltx25:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
case "$ltx25_req" in
    1|true|yes|on)
        if [ -z "$HF_TOKEN" ]; then
            echo "❌ download_ltx25=true but HF_TOKEN is not set; LTX-2.5 is GATED on Hugging Face."
            echo "   ➜ Skipping the LTX-2.5 set and its workflows; continuing on LTX-2.3."
            export download_ltx25=false
            report_off "LTX-2.5" "$LTX25_UNLOCK"
        elif ! curl -sfI --max-time 30 -H "Authorization: Bearer $HF_TOKEN" \
                "$LTX25_PROBE_URL" >/dev/null 2>&1; then
            echo "❌ LTX-2.5 is unavailable to this HF_TOKEN (license not accepted, or HF unreachable)."
            echo "   ➜ Skipping the LTX-2.5 set and its workflows; continuing on LTX-2.3 (fail-open)."
            export download_ltx25=false
            report_off "LTX-2.5" "$LTX25_UNLOCK"
        else
            echo "✅ LTX-2.5 access confirmed; queueing the LTX-2.5 set (~52 GB, first boot is slow)."
        fi
        ;;
    *)
        echo "⏭️  download_ltx25 not set; skipping the LTX-2.5 model set."
        ;;
esac

# --- both model sets off -----------------------------------------------------
# Both sets off leaves a ComfyUI with no LTX weights at all. That is a
# legitimate choice (bring your own via the CivitAI vars), but far more often
# a mistake, so say so plainly (ported from the pre-migration
# src/start.sh:236-239). Deliberately AFTER the preflight, like the original:
# a blocked 2.5 ask with 2.3 disabled must warn too.
ltx25_now="$(printf '%s' "${download_ltx25:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
if [ "$(printf '%s' "${download_ltx23:-true}" | tr '[:upper:]' '[:lower:]')" = "false" ]; then
    case "$ltx25_now" in
        1|true|yes|on) ;;
        *)
            echo "⚠️  Both download_ltx23=false and download_ltx25 off: no LTX model set will be downloaded. Set one of them unless you are supplying your own models."
            report_warn "No LTX model set is downloading. download_ltx23 is false and download_ltx25 is off. Set one of them unless you are supplying your own models."
            ;;
    esac
fi

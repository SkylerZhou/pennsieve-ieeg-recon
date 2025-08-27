#!/usr/bin/env bash
set -Eeuo pipefail

# FSL env (best effort)
if [ -n "${FSLDIR:-}" ] && [ -f "$FSLDIR/etc/fslconf/fsl.sh" ]; then
  # shellcheck disable=SC1091
  source "$FSLDIR/etc/fslconf/fsl.sh" || true
fi

: "${INPUT_DIR:=/input}"
: "${OUTPUT_DIR:=/output}"
mkdir -p "$OUTPUT_DIR" || true

PY="/opt/conda/bin/python"   # <- use conda python that has pandas/etc

echo "Start of iEEG-recon processing"
echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"

found_any=false
for subj in "$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9]; do
  [ -d "$subj" ] || continue
  found_any=true
  sid="$(basename "$subj")"

  anat_dir="$subj/ses-clinical01/anat"
  ct_dir="$subj/ses-clinical01/ct"
  ieeg_dir="$subj/ses-clinical01/ieeg"
  fs_dir="$subj/derivatives/freesurfer"

  out_dir="$OUTPUT_DIR/$sid"
  mkdir -p "$out_dir"

  t1="";  for cand in "$anat_dir"/*T1*.nii.gz "$anat_dir"/*.nii.gz; do [ -f "$cand" ] && { t1="$cand"; break; }; done
  ct="";  for cand in "$ct_dir"/*.nii.gz "$ct_dir"/*.nii;     do [ -f "$cand" ] && { ct="$cand"; break; }; done
  elec="";for cand in "$ieeg_dir"/*.txt;                      do [ -f "$cand" ] && { elec="$cand"; break; }; done

  modules="1,2,4"; extra_fs=()
  if [ -d "$fs_dir" ]; then
    echo "Found FreeSurfer subject dir: $fs_dir"
    modules="1,2,3,4"
    extra_fs=(--freesurfer-dir "$fs_dir")
  else
    echo "No FreeSurfer subject dir for $sid at $fs_dir; skipping Module 3"
  fi

  set -x
  "$PY" /app/run_ieeg_recon.py \
    --t1 "$t1" \
    --ct "$ct" \
    --elec "$elec" \
    --output-dir "$out_dir" \
    --modules "$modules" \
    "${extra_fs[@]}"
  set +x
done

if ! $found_any; then
  echo "No sub-RID???? found under $INPUT_DIR. Exiting 0."
fi

echo "[done] iEEG-recon processing complete."
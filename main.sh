#!/usr/bin/env bash


### SETUP
set -Eeuo pipefail

: "${INPUT_DIR:="/input"}"
: "${OUTPUT_DIR:="/output"}"

# Activate the conda env and load FSL env
#source /opt/conda/bin/activate base
source $FSLDIR/etc/fslconf/fsl.sh

echo "Start of iEEG-recon processing"
echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"


### FILES AND DIRECTORIES
# loop through subjects 
found_any=false
for subj in "$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9]; do
  [ -d "$subj" ] || continue
  found_any=true
  sid="$(basename "$subj")"

  anat_dir="$subj/ses-clinical01/anat"
  ct_dir="$subj/ses-clinical01/ct"
  ieeg_dir="$subj/ses-clinical01/ieeg"

  # output directory
  out_dir="$OUTPUT_DIR/$sid"
  mkdir -p "$out_dir"

  # select files to use
  t1=""
  for cand in "$anat_dir"/*T1*.nii.gz "$anat_dir"/*.nii.gz; do
    [ -f "$cand" ] && { t1="$cand"; break; }
  done

  ct=""
  for cand in "$ct_dir"/*.nii.gz "$ct_dir"/*.nii; do
    [ -f "$cand" ] && { ct="$cand"; break; }
  done

  elec=""
  for cand in "$ieeg_dir"/*.txt; do
    [ -f "$cand" ] && { elec="$cand"; break; }
  done


  # ---- Revised: for debugging MODULE 3 error freesurfer
  fs_dir="$subj/derivatives/freesurfer"

  modules="1,2,4"          # default: skip 3 if FS subject not present
  extra_fs=()              # extra args array

  if [ -d "$fs_dir" ]; then
    echo "Found FreeSurfer subject dir: $fs_dir"
    modules="1,2,3,4"
    extra_fs=(--freesurfer-dir "$fs_dir")
  else
    echo "No FreeSurfer subject dir for $sid at: $fs_dir (will run modules $modules)"
  fi

  PY="/app/.venv/bin/python"
  if [ ! -x "$PY" ]; then
    PY="$(command -v python3 || command -v python)"
    echo "[WARN] /app/.venv/bin/python not found; using $PY"
  fi

  set -x
  /app/.venv/bin/python /app/run_ieeg_recon.py \
    --t1 "$t1" \
    --ct "$ct" \
    --elec "$elec" \
    --output-dir "$out_dir" \
    --modules "$modules" \
    "${extra_fs[@]}"
  set +x
  # ---- End revised

done

if ! $found_any; then
  echo "Failed to find sub-RIDXXXX under $INPUT_DIR."
fi

echo "[done] iEEG-recon processing complete."

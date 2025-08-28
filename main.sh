#!/usr/bin/env bash



### SETUP
set -Eeuo pipefail

# Activate the conda env and load FSL env
source $FSLDIR/etc/fslconf/fsl.sh
echo "Debug: INPUT_DIR is set to $INPUT_DIR"
echo "Debug: INPUT_DIR is set to $INPUT_DIR"



### LOOP THROUGH SUBJECTS 
found_any=false
for subj in "$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9]; do
  [ -d "$subj" ] || continue
  found_any=true
  sid="$(basename "$subj")"

  # format input filepath 
  anat_dir="$subj/ses-clinical01/anat"
  ct_dir="$subj/ses-clinical01/ct"
  ieeg_dir="$subj/ses-clinical01/ieeg"

  # format output directory
  out_dir="$OUTPUT_DIR/$sid"
  mkdir -p "$out_dir"

  # DEBUGGING
  echo "Anatomical directory: $anat_dir"
  echo "CT directory: $ct_dir"
  echo "iEEG directory: $ieeg_dir"
  echo "Output directory: $out_dir"

  # preventive coding to fetch all files needed for run_ieeg_recon.py
  select files to use
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


  # ---- Debugging: for debugging MODULE 3 error freesurfer
  fs_dir="$subj/derivatives/freesurfer"

  modules="1,2,4"  # default: skip 3 if FS subject not present
  extra_fs=()             

  # if cannot find freesurfer, skip module 3
  if [ -d "$fs_dir" ]; then
    echo "Found FreeSurfer subject dir: $fs_dir"
    modules="1,2,3,4"
    extra_fs=(--freesurfer-dir "$fs_dir")
  else
    echo "No FreeSurfer subject dir for $sid at: $fs_dir (will run modules $modules)"
  fi

  # if venv python not found, search the PATH for another python3 or python
  PY="/service/.venv/bin/python"
  if [ ! -x "$PY" ]; then
    PY="$(command -v python3 || command -v python)"
    echo "[WARN] /service/.venv/bin/python not found; using $PY"
  fi

  set -x
  "$PY" /service/run_ieeg_recon.py \
    --t1 "$t1" \
    --ct "$ct" \
    --elec "$elec" \
    --output-dir "$out_dir" \
    --modules "$modules" \
    "${extra_fs[@]}"
  set +x
  # ---- End Debugging

done


echo "[done] iEEG-recon processing complete."

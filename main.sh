#!/usr/bin/env bash



### SETUP
set -Eeuo pipefail

# Activate the conda env and load FSL env
source $FSLDIR/etc/fslconf/fsl.sh
echo "Debug: INPUT_DIR is set to $INPUT_DIR"
echo "Debug: OUTPUT_DIR is set to $OUTPUT_DIR"

# Debugging: Check if INPUT_DIR is a single sub-RIDXXXX folder or a parent directory
if [[ "$(basename "$INPUT_DIR")" =~ sub-RID[0-9]{4} ]]; then
  echo "Debug: INPUT_DIR is a single sub-RIDXXXX folder: $INPUT_DIR"
  sub_dirs=("$INPUT_DIR")
else
  echo "Debug: INPUT_DIR is a parent directory. Checking for sub-RIDXXXX folders."
  sub_dirs=("$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9])
fi

# Check if any sub-RIDXXXX directories are found if INPUT_DIR is a parent directory
if [ -d "${sub_dirs[0]}" ]; then
  echo "Debug: Found sub-RIDXXXX directories or folder."
else
  echo "Error: No sub-RIDXXXX directories found in $INPUT_DIR."
  exit 1
fi

### LOOP THROUGH SUBJECTS
found_any=false
for subj in "${sub_dirs[@]}"; do
  [ -d "$subj" ] || continue
  found_any=true
  sid="$(basename "$subj")"
  
  echo "Subject file directory: $subj"
  echo "Subject ID: $sid"

  # format input filepath 
  anat_dir="$subj/ses-clinical01/anat"
  ct_dir="$subj/ses-clinical01/ct"
  ieeg_dir="$subj/ses-clinical01/ieeg"

  # format output directory
  if [[ "$(basename "$INPUT_DIR")" =~ sub-RID[0-9]{4} ]]; then
    # Case 1: INPUT_DIR is a single sub-RIDXXXX folder
    out_dir="$OUTPUT_DIR"
  else
    # Case 2: INPUT_DIR is a parent directory containing sub-RIDXXXX folders
    out_dir="$OUTPUT_DIR/$sid"
  fi

  # Create the output directory if it doesn't exist
  mkdir -p "$out_dir"

  # DEBUGGING
  echo "Anatomical directory: $anat_dir"
  echo "CT directory: $ct_dir"
  echo "iEEG directory: $ieeg_dir"
  echo "Output directory: $out_dir"

  # preventive coding to fetch all files needed for run_ieeg_recon.py
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

  # ---- Debugging: Check output directory contents ----
  if [ -d "$out_dir" ]; then
    echo "Debug: Output directory exists: $out_dir"
    echo "Debug: Listing contents of $out_dir:"
    ls -l "$out_dir/ieeg_recon/"
  else
    echo "Error: Output directory was not created: $out_dir"
  fi

  # ---- End Debugging
done


if [ "$found_any" = false ]; then
  echo "Error: No valid sub-RIDXXXX directories found in $INPUT_DIR."
  exit 1
fi

echo "[done] iEEG-recon processing complete."

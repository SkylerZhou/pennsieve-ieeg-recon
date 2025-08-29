#!/usr/bin/env bash

### SETUP
set -Eeuo pipefail

# Activate the conda env and load FSL env
source $FSLDIR/etc/fslconf/fsl.sh
echo "Debug: INPUT_DIR is set to $INPUT_DIR"
echo "Debug: OUTPUT_DIR is set to $OUTPUT_DIR"

# Debugging: Check if INPUT_DIR is a parent folder or a single sub-RIDXXXX folder
if ls "$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9] >/dev/null 2>&1; then
  # Case 1: If there are any dir or files in INPUT_DIR that match the pattern sub-RIDXXXX
  echo "Debug: INPUT_DIR bundles up all sub-RIDXXXX. Checking for sub-RIDXXXX folders."
  in_dir=("$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9])
elif [ -d "$INPUT_DIR/ses-clinical01" ]; then
  # Case 2: If under INPUT_DIR there is ses-clinical01 folder (INPUT_DIR is potentially renamed)
  echo "Debug: INPUT_DIR is a single sub-RIDXXXX folder (potentially renamed): $INPUT_DIR"
  in_dir=("$INPUT_DIR")
fi

### SELECT FILES TO BE INPUTED INTO run_ieeg_recon.py
found_any=false
for subj in "${in_dir[@]}"; do
  [ -d "$subj" ] || continue
  found_any=true

  if [[ "${in_dir[@]}" == "$INPUT_DIR" ]]; then
    # Case 1: INPUT_DIR is a single sub-RIDXXXX folder
    anat_dir="$INPUT_DIR/ses-clinical01/anat"
    ct_dir="$INPUT_DIR/ses-clinical01/ct"
    ieeg_dir="$INPUT_DIR/ses-clinical01/ieeg"
    out_dir="$OUTPUT_DIR"
  else
    # Case 2: INPUT_DIR is a parent directory containing sub-RIDXXXX folders
    sid="$(basename "$subj")"
    anat_dir="$subj/ses-clinical01/anat"
    ct_dir="$subj/ses-clinical01/ct"
    ieeg_dir="$subj/ses-clinical01/ieeg"
    out_dir="$OUTPUT_DIR/$sid"
  fi

  # Create the output directory if it doesn't exist
  mkdir -p "$out_dir"

  # DEBUGGING
  echo "Anatomical directory: $anat_dir"
  echo "CT directory: $ct_dir"
  echo "iEEG directory: $ieeg_dir"
  echo "Output directory: $out_dir"

  # Set paths for input files
  t1_files=("$anat_dir"/*.nii.gz)
  ct_files=("$ct_dir"/*.nii.gz)
  elec_files=("$ieeg_dir"/*.txt)

  # Check if files exist
  if [ -e "${t1_files[0]}" ]; then
    t1="${t1_files[0]}"  
  else
    echo "Error: No T1 .nii.gz files found in $anat_dir"
    exit 1
  fi
  if [ -e "${ct_files[0]}" ]; then
    ct="${ct_files[0]}"  
  else
    echo "Error: No CT .nii.gz files found in $ct_dir"
    exit 1
  fi
  if [ -e "${elec_files[0]}" ]; then
    elec="${elec_files[0]}"  
  else
    echo "Error: No electrode .txt files found in $ieeg_dir"
    exit 1
  fi

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
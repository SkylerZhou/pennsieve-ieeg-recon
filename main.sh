#!/usr/bin/env bash

### SETUP
set -Eeuo pipefail

# Activate the conda env and load FSL env
source $FSLDIR/etc/fslconf/fsl.sh
echo "Debug: INPUT_DIR is set to $INPUT_DIR"
echo "Debug: OUTPUT_DIR is set to $OUTPUT_DIR"


# Run the analysis
PY="/service/.venv/bin/python"
if [ ! -x "$PY" ]; then
  PY="$(command -v python3 || command -v python)"
  echo "[WARN] /service/.venv/bin/python not found; using $PY"
fi


# Debugging: Check if INPUT_DIR is a parent folder or a single sub-RIDXXXX folder
if ls "$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9] >/dev/null 2>&1; then
  echo "Debug: INPUT_DIR bundles up all sub-RIDXXXX. Checking for sub-RIDXXXX folders."
  in_dir=("$INPUT_DIR"/sub-RID[0-9][0-9][0-9][0-9])
    for folder in "$INPUT_DIR"/*; do
    if [ -d "$folder" ]; then
      echo "  $folder"
    fi
  done
elif [ -d "$INPUT_DIR/ses-clinical01" ]; then
  echo "Debug: INPUT_DIR is a single sub-RIDXXXX folder (potentially renamed): $INPUT_DIR"
  in_dir=("$INPUT_DIR")
    for folder in "$INPUT_DIR"/*; do
    if [ -d "$folder" ]; then
      echo "  $folder"
    fi
  done
else
  echo "Error: INPUT_DIR does not contain sub-RIDXXXX folders or a valid ses-clinical01 structure."
  echo "Debug: Listing first-level folders in $INPUT_DIR:"
  for folder in "$INPUT_DIR"/*; do
    if [ -d "$folder" ]; then
      echo "  $folder"
    fi
  done
fi


# If in_dir contains only INPUT_DIR, process it directly
if [[ "${in_dir[@]}" == "$INPUT_DIR" ]]; then
  # Case 1: INPUT_DIR is a single sub-RIDXXXX folder
  echo "Processing single sub-RIDXXXX folder: $INPUT_DIR"
  anat_dir="$INPUT_DIR/ses-clinical01/anat"
  ct_dir="$INPUT_DIR/ses-clinical01/ct"
  ieeg_dir="$INPUT_DIR/ses-clinical01/ieeg"
  out_dir="$OUTPUT_DIR"

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

  set -x
  "$PY" /service/run_ieeg_recon.py \
    --t1 "$t1" \
    --ct "$ct" \
    --elec "$elec" \
    --output-dir "$out_dir"
  set +x

else
  # Case 2: INPUT_DIR is a parent directory containing sub-RIDXXXX folders
  for subj in "${in_dir[@]}"; do
    [ -d "$subj" ] || continue

    sid="$(basename "$subj")"
    anat_dir="$subj/ses-clinical01/anat"
    ct_dir="$subj/ses-clinical01/ct"
    ieeg_dir="$subj/ses-clinical01/ieeg"
    out_dir="$OUTPUT_DIR/$sid"

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

    # Run the analysis
    set -x
    "$PY" /service/run_ieeg_recon.py \
      --t1 "$t1" \
      --ct "$ct" \
      --elec "$elec" \
      --output-dir "$out_dir"
    set +x
  done
fi

echo "[done] iEEG-recon processing complete."
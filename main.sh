#!/usr/bin/env bash


### SETUP
set -Eeuo pipefail

# Activate the conda env and load FSL env
#source /opt/conda/bin/activate base
source $FSLDIR/etc/fslconf/fsl.sh

echo "Start of iEEG-recon processing"
echo "INPUT_DIR=$INPUT_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"

# added for debugging
echo "Checking executable paths..."
which greedy || echo "greedy not in PATH"
which c3d || echo "c3d not in PATH"
which antsRegistration || echo "antsRegistration not in PATH"

echo "Testing executables directly..."
/itksnap/greedy --help > /dev/null 2>&1 && echo "/itksnap/greedy works" || echo "/itksnap/greedy failed"
greedy --help > /dev/null 2>&1 && echo "greedy in PATH works" || echo "greedy in PATH failed"

ls -la /itksnap/bin/ || echo "/itksnap/bin/ not found"
ls -la /itksnap/greedy/ || echo "/itksnap/greedy/ not found"

# Check library dependencies
#echo "Checking ldd for greedy..."
#ldd /usr/local/bin/greedy | head -5



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


### RUN CODE 
  set -x
  /app/.venv/bin/python /app/run_ieeg_recon.py \
    --t1 "$t1" \
    --ct "$ct" \
    --elec "$elec" \
    --output-dir "$out_dir" 
  set +x

done

if ! $found_any; then
  echo "Failed to find sub-RIDXXXX under $INPUT_DIR."
fi

echo "[done] iEEG-recon processing complete."

#!/bin/bash
#SBATCH --time 00:30:00
#SBATCH -p project
#SBATCH -o compile_output_%j.out
#SBATCH -e compile_output_%j.err

#config
# SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# CONFIG_FILE="$PROJECT_DIR/config/config.env"

#inputs
blcm_preds=$1
mlst_results=$2
fimh_results=$3
hep_elements=$4
output_dir=$5
# Config file as last argument
config_file_local="/dpssi/data/Projects/mtg_host_elements_files_and_output/proj/general_JonThesis/Food-epidemiology/host_element_V3/config/config.env"
config_file=${6:-${config_file_local}}

#paths 
project_root=$(grep '^GLOBAL__PROJECT_ROOT__=' "$config_file" | awk -F'__=' '{print $2}')
compile_script="$project_root/run_full_pipeline/helper_scripts/compile_blcm_output_csvfile.R"

#conda
conda_source=$(grep "^GLOBAL__CONDA_SH__=" "$config_file" | awk -F'__=' '{print $2}')
conda_env_r_basics=$(grep "^BLCM__R_BASICS_ENV__=" "$config_file" | awk -F'__=' '{print $2}')


if [ -z "$blcm_preds" ] || [ -z "$mlst_results" ] || [ -z "$fimh_results" ] || [ -z "$hep_elements" ] || [ -z "$output_dir" ]; then
    echo "Usage: sbatch run_compile_blcm_output.sh <blcm_pred_scores.csv> <mlst_results.txt> <fimh_results.txt> <element_presence.tsv> <output_dir>"
    exit 1
fi

. "$conda_source"
conda activate "$conda_env_r_basics"

Rscript "$compile_script" \
    -b "$blcm_preds" \
    -m "$mlst_results" \
    -f "$fimh_results" \
    -e "$hep_elements" \
    -o "$output_dir"

#move slurm files
mv "compile_output_${SLURM_JOB_ID}.out" "$output_dir" 2>/dev/null
mv "compile_output_${SLURM_JOB_ID}.err" "$output_dir" 2>/dev/null

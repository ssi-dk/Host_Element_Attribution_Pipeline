#!/bin/bash
#SBATCH --time=2-00:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH -o blcm_analysis_%j.out
#SBATCH -e blcm_analysis_%j.err


#blcm pipeline wrapper, written by Jon Slotved on 02/04/2026
#please contact via: JOSS@dksund.dk

#get input
input_folder="$1"
host_info="$2"
main_output_folder=${3:-OUTPUT_BLCA}
partition=${4:-project}
# Config file as last argument
config_file_local="/dpssi/data/Projects/mtg_host_elements_files_and_output/proj/general_JonThesis/Food-epidemiology/host_element_V3/config/config.env"
config_file=${5:-${config_file_local}}

#paths
project_root=$(grep "^GLOBAL__PROJECT_ROOT__=" "$config_file" | awk -F'__=' '{print $2}' | xargs)
#echo "main path: $project_root"

#how to use 
print_usage() {
    echo
    echo "Usage: sbatch/bash BLCM_analysis.sh <assembly_folder> <host_tsv> [output_directory] [partition]"
    echo
    echo "Arguments:"
    echo "  assembly_folder  Folder containing genome assemblies in fasta/fa/fna format"
    echo "  host_tsv         TSV file with two columns: sampleID and Host"
    echo "  output_directory Destination folder for intermediate and final outputs (optional, default: creates OUTPUT_BLCA in current dir)"
    echo "  partition        SLURM partition to use (optional, default: project)"
    echo
    echo "PLEASE NOTE: avoid unusual filenames with spaces, commas or dots"
    echo "PLEASE NOTE: It is also recommended that full paths are used when filling arguments"
    echo 
}

#check input and print_usage if bad
if [ -z "$input_folder" ] || [ -z "$host_info" ]; then
    print_usage
	echo
	echo "found information:"
	echo "input_folder: ${input_folder}"
	echo "host_info: ${host_info}"
	echo "output_loc: ${main_output_folder} (creates OUTPUT_BLCA if no output folder is set)"
	echo "partition: ${partition} (default: project)"
    exit 1
fi


#create file system
input_folder=$(cd "$input_folder" && pwd)
host_info=$(readlink -f "$host_info")
mkdir -p "$main_output_folder"
main_output_folder=$(cd "$main_output_folder" && pwd)
mkdir -p "$main_output_folder/tmp_analysis"
cd "$main_output_folder" || { echo "ERROR: cannot cd to $main_output_folder"; exit 1; }
# cat "$host_info" | awk -F'\t' '{print $1}' | sed 's/$/\.fasta/' | tail -n +2 > tmp_analysis/sample_list.txt

#clean host_info input
echo -e "Genome_Ref\tHost" > "$main_output_folder/tmp_analysis/host_info_clean.tsv"
tail -n +2 | cut -f1,2 "$host_info" >> "$main_output_folder/tmp_analysis/host_info_clean.tsv"
host_info_clean="$main_output_folder/tmp_analysis/host_info_clean.tsv"

awk -F'\t' 'NR>1{print $1}' "$host_info" | while read -r sample; do
    found_isolate=$(ls "$input_folder"/"$sample".f*)
    basename $found_isolate
done > "$main_output_folder/tmp_analysis/sample_list.txt"

sample_list="$main_output_folder/tmp_analysis/sample_list.txt"

#run modules

#cgmlst
#1 folder with fasta files
#2 list of samples to run analysis on (takes ffrom )
#3 SLURM job_name
#4 partition
#5 config.env
cgmlst="$project_root/pipeline_modules/cgmlstFinder"
cgmlst_compiler_jid=$(bash "$cgmlst/cgmlstFinder_Submitter.sh" \
    "$input_folder" \
    "$sample_list" \
    cgmlst_analysis \
    "$partition" \
    "$config_file" | tail -1)
echo "cgmlst compiler: $cgmlst_compiler_jid"

#host element pipeline
#1 folder with fasta files
#2 list of samples to run analysis on (takes ffrom )
#3 host_tsv file
#4 SLURM job_name
#5 partition
#6 dependecny flag "empty if no dependency"
#7 config.env
hep="$project_root/pipeline_modules/host_element_pipeline/scripts"
hep_caller_jid=$(bash "$hep/host_element_pipeline_Submitter.sh" \
    "$input_folder" \
    "$sample_list" \
    "$host_info_clean" \
    hep_analysis \
    "$partition" \
    "" \
    "$config_file" | tail -1)
echo "HEP caller (dependecy_flag): $hep_caller_jid"

#mlst analysis
#1 folder with fasta files
#2 list of samples to run analysis on (takes ffrom )
#3 SLURM job_name
#4 partition
#5 dependecny flag "empty if no dependency"
#6 config.env
mlst="$project_root/pipeline_modules_nonessential/MLST/MLST_SLURM"
mlst_compiler_jid=$(bash "$mlst/Slurm_Array_Submitter.sh" \
    "$input_folder" \
    "$sample_list" \
    mlst_analysis \
    "$partition" \
    "" \
    "$config_file" | tail -1)
echo "MLST compiler (dependecy_flag): $mlst_compiler_jid"

#fimhtyper
fimh="$project_root/pipeline_modules_nonessential/fimHtyper/fimHtyper_SLURM"
#1 folder with fasta files
#2 list of samples to run analysis on (takes ffrom )
#3 SLURM job_name
#4 partition
#5 dependecny flag "empty if no dependency"
#6 config.env
fimh_compiler_jid=$(bash "$fimh/Slurm_Array_Submitter.sh" \
    "$input_folder" \
    "$sample_list" \
    fimhtyper_analysis \
    "$partition" \
    "" \
    "$config_file" | tail -1)
echo "fimHtyper compiler (dependecy_flag): $fimh_compiler_jid"

#kmodes
#1 kmodes input file
#2 partition
#3 dependecny flag "kmodes always runs after cgmlst!"
#4 config.env
kmodes="$project_root/pipeline_modules/kmodes"
kmodes_rdy_inputfile="$main_output_folder/cgmlst_analysis_output/compiled_files/cgmlst_analysis_kmodes_ready_inputfile.txt"
kmodes_pred_jid=$(bash "$kmodes/kmodes_SLURM_Submitter.sh" \
    "$kmodes_rdy_inputfile" \
    "$partition" \
    "$cgmlst_compiler_jid" \
    "$config_file" | tail -1)
echo "kmodes pred (dependecy_flag): $kmodes_pred_jid"

#blcm
blcm="$project_root/pipeline_modules/host_element_blcm/SB27_excludeBeefnTurkey_18022026"
#combine all input from previous analysis
kmodes_predictions="$main_output_folder/cgmlst_analysis_output/compiled_files/cgmlst_analysis_kmodes_ready_inputfile__Cluster_2__kmodes_cgmlst_clustering_predictions.csv"
hep_elements="$main_output_folder/hep_analysis_output/compiled_files/hep_analysis_element_presence.tsv"
mlst_results="$main_output_folder/mlst_analysis_output/compiled_files/results_compiled.txt"
#1 kmodes input file
#2 partition
#3 dependecny flag "kmodes always runs after cgmlst!"
#4 config.env
blcm_jid=$(sbatch --parsable \
    --dependency=afterok:${kmodes_pred_jid}:${hep_caller_jid}:${mlst_compiler_jid} \
    -p "$partition" \
    "$blcm/run_hostelement_blca.sh" \
    "$kmodes_predictions" \
    "$hep_elements" \
    "$host_info_clean" \
    "$mlst_results" \
    "$main_output_folder/blcm_output" \
	"$config_file")
echo "BLCM (dependecy_flag): $blcm_jid"

#compile final output csv
compile_script="$project_root/run_full_pipeline/helper_scripts/run_compile_blcm_output.sh"
blcm_pred_scores="$main_output_folder/blcm_output/blcm_output_pred_scores.csv"
fimh_results="$main_output_folder/fimhtyper_analysis_output/compiled_files/results_compiled.txt"

compile_jid=$(sbatch --parsable \
    --dependency=afterok:${blcm_jid}:${fimh_compiler_jid} \
    -p "$partition" \
    "$compile_script" \
    "$blcm_pred_scores" \
    "$mlst_results" \
    "$fimh_results" \
    "$hep_elements" \
    "$main_output_folder" \
	"$config_file")
echo "Compile output: $compile_jid"

echo
echo "========================================"
echo "Jobs submitted:"
echo "all jobs should show IDS below. If they don't, restart the script and cancel what you currently is running with [scancel -u <your_name>]"
echo "If they still don't show after a rerun, contact Jon Slotved (JOSS@dksund.dk)"
echo "  cgmlst compiler JID : $cgmlst_compiler_jid"
echo "  HEP  caller JID      : $hep_caller_jid"
echo "  MLST compiler JID   : $mlst_compiler_jid"
echo "  fimHtyper compiler JID : $fimh_compiler_jid"
echo "  kmodes pred JID        : $kmodes_pred_jid"
echo "  BLCM JID               : $blcm_jid"
echo "  Compile output JID     : $compile_jid"
echo "========================================"




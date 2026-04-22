#!/bin/bash
#SBATCH -e Slurm_Array_Submitter_%j.err
#SBATCH -o Slurm_Array_Submitter_%j.out
#SBATCH --time 30:00

# created by Jon slotved

# User Inputs
Data_Folder_input=$1
Data_Folder_Samplelist_input=$2
Job_Name_input=$3
Partition_input=${4:-project}  # optional; defaults to "project"
dependency=${5:-}
#config file as last argument
config_file_local="/dpssi/data/Projects/mtg_host_elements_files_and_output/proj/Host_Element_Attribution_Pipeline/Food-epidemiology/host_element_V3/config/config.env"
config_file=${6:-${config_file_local}}

# Script Locations (Path to where all slurm-array scripts live, use `pwd` to find path.
project_root=$(grep '^GLOBAL__PROJECT_ROOT__=' "$config_file" | awk -F'__=' '{print $2}')
Slurm_Array_scripts="$project_root/pipeline_modules_nonessential/fimHtyper/fimHtyper_SLURM"



dep_flag=""
if [ -n "$dependency" ]; then
   dep_flag="--dependency=afterok:${dependency}"
fi

# Names the slurm job, as well as used in the singleton dependency
jobname=${Job_Name_input}


# Start-Up / Generate SLURM-ARRAY-READY samplelist
# Convert samplelist to SLURM-ARRAY-READY format: appends indexing and __@__ to each sample name in file
bash "$Slurm_Array_scripts/Slurm_Array_SampleListReady.sh" "$Data_Folder_Samplelist_input"
samplelist_filename=$(basename "${Data_Folder_Samplelist_input%.*}") # Strip path and extension; array-ready file goes in current dir
if [ ! -f "${samplelist_filename}_SLURM-ARRAY-READY.txt" ]; then
   echo "Error: failed to generate ${samplelist_filename}_SLURM-ARRAY-READY.txt"
   exit 1
fi
echo 
echo


# Create File System
mkdir -p "${Job_Name_input}_output"
mkdir -p "${Job_Name_input}_output/processing_files"
mkdir -p "${Job_Name_input}_output/slurm"
if [ -n "$SLURM_JOB_ID" ]; then
   mv "Slurm_Array_Submitter_${SLURM_JOB_ID}.out" "${Job_Name_input}_output/slurm"
   mv "Slurm_Array_Submitter_${SLURM_JOB_ID}.err" "${Job_Name_input}_output/slurm"
fi

#move SLURM-ARRAY-READY file into job output folder to avoid collisions when multiple modules run from the same current wd
mv "${samplelist_filename}_SLURM-ARRAY-READY.txt" "${Job_Name_input}_output/"
slurm_array_ready_file="${Job_Name_input}_output/${samplelist_filename}_SLURM-ARRAY-READY.txt"

# SLURM array settings
numFiles=$(cat "$slurm_array_ready_file" | wc -l) # Total number of samples
Slurm_MaxArraySize=1000 # Maximum number of tasks allowed in one array job

# Calculate how many array jobs are needed
if (( $numFiles % $Slurm_MaxArraySize == 0 ))
then
   Slurm_chunks=`expr $numFiles / $Slurm_MaxArraySize`
else
   Slurm_chunks=`expr $numFiles / $Slurm_MaxArraySize + 1` # Round up to the next whole number
fi

# Set how many tasks to run at the same time for each array job
# Adjust these values to match your cluster setup
# Example: if the sample list has 1000 files, it submits 1 array job and runs up to 12 tasks at once.
# Example: if the sample list has 10000 files, it submits 10 array jobs and runs 1 task at once for each job.
if [ $Slurm_chunks == 1 ]
then
   Slurm_CalcRunParallel=12

elif [ $Slurm_chunks == 2 ]
then
   Slurm_CalcRunParallel=6

elif [ $Slurm_chunks == 3 ]
then
   Slurm_CalcRunParallel=4

elif [ $Slurm_chunks == 4 ]
then
   Slurm_CalcRunParallel=3

elif [ $Slurm_chunks == 5 ]
then
   Slurm_CalcRunParallel=2

elif [ $Slurm_chunks == 6 ]
then
   Slurm_CalcRunParallel=2

else
   Slurm_CalcRunParallel=1
fi

# Manually Set Slurm_CalcRunParallel for this special case (to speed up process)
# If you need to speed-up the process, you can manually select the number of nodes to be used per SlurmArray job.
# Uncomment (delete the #) and type in your int number.
# Slurm_CalcRunParallel=5


# Splits up the samplelist by index_set and runs the SlurmArray jobs based on the start and end of each set
for ((i=0; i<$Slurm_chunks; i++))
do
   # Tracks the index_set number for the samplelist (First number)
   index_set=$i

   # Identifes the start and end of the array to be submitted
   array_start="$(cat "$slurm_array_ready_file" | grep "^${i}__" | head -1 | awk -F "__@__" '{print $2}')"
   array_end="$(cat "$slurm_array_ready_file" | grep "^${i}__" | tail -1 | awk -F "__@__" '{print $2}')"
   
   # Submit the jobs to HPC
   echo "sbatch --array=${array_start}-${array_end}%${Slurm_CalcRunParallel} --partition=${Partition_input} -J $jobname $Slurm_Array_scripts/Slurm_Array_Runner.sh $Data_Folder_input $slurm_array_ready_file $index_set ${Job_Name_input}_output $config_file"
   sbatch --array=$array_start-$array_end%$Slurm_CalcRunParallel $dep_flag --partition="$Partition_input" -J "$jobname" "$Slurm_Array_scripts/Slurm_Array_Runner.sh" "$Data_Folder_input" "$slurm_array_ready_file" "$index_set" "${Job_Name_input}_output" "$config_file"
done

# Compile the results data and Clean-up file system script
compiler_jid=$(sbatch --parsable --dependency=singleton --partition="$Partition_input" -J "$jobname" "$Slurm_Array_scripts/Slurm_Array_Compiler.sh" "${Job_Name_input}_output")

echo "---------- Your jobs have been submitted to HPC, thank you. ----------"

#echo id for downstream depency flags (must be the last std in script!)
echo "$compiler_jid"

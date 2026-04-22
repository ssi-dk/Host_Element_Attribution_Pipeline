# fimHtyper_SLURM (Simple Guide)

Scripts to run FimTyper on many fasta files using SLURM arrays.

## Main Scripts

- Slurm_Array_Submitter.sh: Prepares and submits jobs
- Slurm_Array_SampleListReady.sh: Prepares sample list
- Slurm_Array_Runner.sh: Runs FimTyper for each sample
- Slurm_Array_Compiler.sh: Compiles results

## Requirements

- SLURM with sbatch
- Conda
- FimTyper and database installed
- Config file: see config.env path in scripts

## Usage

From this folder, run:

    sbatch Slurm_Array_Submitter.sh <data_folder> <sample_list.txt> <job_name> [partition]

Example:

    sbatch Slurm_Array_Submitter.sh /path/to/data sample_list.txt test

## sample_list.txt Example

This file should contain one fasta filename per line, matching files in your data folder. Example:

    sample1.fasta
    sample2.fasta
    sample3.fasta

No headers, just filenames.

## Output

Results are in `<job_name>_output/`.
Compiled results: `results_compiled.txt`

## Notes

- FimTyper uses parameters: `-k 95.00 -l 0.60`
- Sample list must match fasta filenames
- Max 1000 samples per SLURM array
- If rerunning, remove `<sample_list_basename>_SLURM-ARRAY-READY.txt` to avoid duplicates

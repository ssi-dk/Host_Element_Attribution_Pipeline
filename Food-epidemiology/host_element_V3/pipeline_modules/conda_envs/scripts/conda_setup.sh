#!/bin/bash


#setup script for the BLCA_analysis conda environment
#creates the env, symlinks the BLCA command, and sets BLCA_CONFIG on activate
#usage:
#  bash conda_setup.sh [path/to/config.env]
#If a config file is provided as the first argument, it will be used for BLCA_CONFIG.
#Otherwise, the default config file is used.

#written by Jon Slotved (JOSS@dksund.dk)

set -e


SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_YML="$PROJECT_DIR/pipeline_modules/conda_envs/BLCA_analysis.yml"
BLCA_SCRIPT="$PROJECT_DIR/pipeline_modules/conda_envs/scripts/BLCA"

CONFIG_FILE="$1"

if [ $# -lt 1 ];
then
    echo "add config as input conda_setup.sh <path/to/config.env>"
fi
# Allow user to specify config file as first argument
# echo "Script dir:####################################"
# echo "${SCRIPT_DIR}"
# echo
# echo "proj dir:####################################"
# echo "${PROJECT_DIR}"
# echo 
# echo "executable yml env:###########################"
# echo "${ENV_YML}"
# echo
# echo "BLCA script:############################"
# echo "${BLCA_SCRIPT}"

if [ ! -f "$ENV_YML" ]; then
    echo "ERROR: env yml not found: $ENV_YML"
    exit 1
fi

#create conda env
echo "creating BLCA_analysis conda environment."
conda env create -f "$ENV_YML"

#get conda env path
CONDA_PREFIX=$(conda info --envs | grep "BLCA_analysis" | awk '{print $NF}')
echo "getting path to the conda env"
echo "$CONDA_PREFIX"

echo 
echo


if [ -z "$CONDA_PREFIX" ]; then
    echo "ERROR: could not find BLCA_analysis env path"
    exit 1
fi

#symlink BLCA into env bin
chmod +x "$BLCA_SCRIPT"
ln -sf "$BLCA_SCRIPT" "$CONDA_PREFIX/bin/BLCA"
echo "creating a symlink of the BLCA executable (${BLCA_SCRIPT}) at (${CONDA_PREFIX}/bin/BLCA)"
echo 


#set BLCA_CONFIG on conda activate
mkdir -p "$CONDA_PREFIX/etc/conda/activate.d"
echo "export BLCA_CONFIG=\"$CONFIG_FILE\"" > "$CONDA_PREFIX/etc/conda/activate.d/blca_env_vars.sh"

#unset on deactivate
#unset "unsets variables" meaning the config var is unset anew every time someone deactivates the env
mkdir -p "$CONDA_PREFIX/etc/conda/deactivate.d"
echo "unset BLCA_CONFIG" > "$CONDA_PREFIX/etc/conda/deactivate.d/blca_env_vars.sh"


echo
echo "Setup complete!"
echo "Usage:"
echo "  bash conda_setup.sh [path/to/config.env]"
echo "  conda activate BLCA_analysis"
echo "  BLCA <assembly_folder> <host_tsv> [output_directory] [partition] [config_file]"
echo
echo "If you want to use a custom config file, provide it as the first argument to conda_setup.sh."

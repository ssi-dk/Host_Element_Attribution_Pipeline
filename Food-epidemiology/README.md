# Installation Steps

These step are made for installing on SSIs ugerm HPC

This repo is a fork of https://github.com/Jonedrengen/general_JonThesis, which itself is a fork of https://github.com/araclab/general 

author: Jon Slotved (JOSS@dksund.dk)

date: 22/04/2026

1. **Clone the repository**
	```sh
	git clone <repository-url>
	cd <repository-directory>
	```

2. **Set up the environment**
	- (If using conda)
    - there are multiple environments to install
	  ```sh
	  conda env create -f <environment-file>.yml
	  conda activate <env-name>
	  ```
	- fimtyper has to be installed on its own, since env export is not possible https://bitbucket.org/genomicepidemiology/fimtyper/src/master/
	- mlstfinder 
	- xx
	- you should still install it in an environment and fill out the config.env

fimtyper requires manual install

3. **Configure environment variables**
	- Copy the example config and edit as needed:
	  ```sh
	  cp config/config.env.example config/config.env
	  # Edit config/config.env with your settings
	  ```

4. **Download required data or models**
	- (If applicable, add instructions here)

5. **Run initial setup or tests**
	```sh
	# Example: Run tests or setup scripts
	python -m unittest
	# or
	bash scripts/setup.sh
	```

6. **Usage**
	- (Add a quick example of how to run the main script or pipeline)


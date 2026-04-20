Recreate the necessary conda environments using:
```
conda env create -n newname -f environment.yml
```
OR
```
conda create --name <env> --file <this file>
```

Do note that most of these conda environments are just following the instructions on the software's installation page. If these conda environments fail, please reach out me (edward.sung@gwu.edu) or try creating a fresh environment following the respective software's installation pages. Sometimes I install additional software to these environments for other pipeline usage, so it may contain more than what you need to run the host_element_pipeline.

UPDATE: 08/04/2026 - Jon Slotved (JOSS@DKSUND.dk)
added a few more envs:
    blcm_R_basics.yml -- has a few basic libs for R, like tidyverse and optpar
    BLCA_analysis.yml -- this is a setup script, that defines the path for the config file

UPDATE: envs to install
```
blcm_R_basics.yml

```
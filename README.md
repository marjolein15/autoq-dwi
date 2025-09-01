Scripts for the automated assessment of artifacts in DWI data using output from FSL's eddy

**Requirements**

DWI data need to be processed with the eddy tool in FSL, including outlier correction. 

R needs to be installed and the preparation script needs to be run on a Linux platform.

**Steps**

- Run the script 'collect_eddyqc_params.sh'. This script expects output from eddy ({subject}.eddy_parameters, {subject}.eddy_movement_rms, {subject}.eddy_restricted_movement_rms, {subject}.eddy_outlier_n_stdev_map, {subject}.eddy_outlier_map)), a nifti with unwarped b0 volumes ({subject}_unwarped_b0s.nii.gz), and a subjectlist with ID numbers/keys.




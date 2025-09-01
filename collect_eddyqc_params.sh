#!/bin/bash

#this script pulls QC variables that are output by eddy and combines them (all variables with a value per volume)

#configurations
#the script assumes that your subject folders are named after the subject id
processed_data_folder=/yourpath/to/processed_data/dwi #folder with eddy output
subjectlist_folder=/yourpath/to/subjectlist/folder #folder with subjectlist
subjectlist=eddyqcparams_subjectlist.txt #subjectlist, one row for each id
output_folder=/yourpath/to/outputfolder #folder where output of this script goes

module load fsl
cd $subjectlist_folder

for subject in `cat $subjectlist` ; do 

subject_folder=$subject
cd $processed_data_folder/${subject_folder}

#${subject}_eddycor.eddy_parameters = trans_x trans_y trans_z rot_x rot_y rot_z ec_x ec_y ec_z ec_quad[xyz] ec_mult[xyx]
#${subject}.eddy_movement_rms = abs_mot rel_mot
#${subject}.eddy_restricted_movement_rms = (ignores PE direction) abs_restrict_mot rel_restrict_mot
#${subject}.eddy_outlier_n_stdev_map = how many SDs off the mean difference between observation and prediction is. remove first line, take average abs value across columns(=slices) and minimum and maximum values across columns
#${subject}.eddy_outlier_map = outliers are ones. remove first line, sum across columns(=slices)

awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9}' ${subject}.eddy_parameters > ${subject}_trans_rot_ec.txt
sed '1d' ${subject}.eddy_outlier_n_stdev_map | tr -d - | awk '{sum = 0; for (i = 1; i <= NF; i++) sum += $i; sum /= NF; print sum}' > ${subject}_outlier_av_sd.txt 
sed '1d' ${subject}.eddy_outlier_n_stdev_map | awk  '{b=0; for (i=1;i<=NF;i++) if ($i > b|| i == 1)b = $i; print b}' > ${subject}_outlier_max_sd.txt 
sed '1d' ${subject}.eddy_outlier_n_stdev_map | awk  '{b=0; for (i=1;i<=NF;i++) if ($i < b|| i == 1)b = $i; print b}' > ${subject}_outlier_min_sd.txt 
sed '1d' ${subject}.eddy_outlier_map | awk '{sum = 0; for (i = 1; i <= NF; i++) sum += $i; print sum}' > ${subject}_outliers.txt 

#tSNR
fslmaths ${subject}_b0s.nii.gz -mas ${subject}_b0_brain_mask.nii.gz -Tstd ${subject}_b0_std.nii.gz 
fslmaths ${subject}_b0_mean.nii.gz -div ${subject}_b0_std.nii.gz ${subject}_tsnr.nii.gz
tsnr=`fslstats ${subject}_tsnr.nii.gz -M`
nvols=`cat ${subject}.eddy_parameters | wc -l`
yes $tsnr | head -n $nvols > ${subject}_tsnr.txt

#combine
yes $subject | head -n $nvols > ${subject}_id.txt
seq 0 $(($nvols - 1)) > ${subject}_vols.txt
paste ${subject}_id.txt ${subject}_vols.txt ${subject}.eddy_movement_rms ${subject}.eddy_restricted_movement_rms ${subject}_trans_rot_ec.txt ${subject}_outlier_av_sd.txt ${subject}_outlier_max_sd.txt ${subject}_outlier_min_sd.txt ${subject}_outliers.txt ${subject}_tsnr.txt > ${subject}_allqc.txt
#columns "ID abs_mot rel_mot abs_restrict_mot rel_restrict_mot trans_x trans_y trans_z rot_x rot_y rot_z ec_x ec_y ec_z outliers_av_sd outliers_max_sd outliers_n tsnr"


done

cat $processed_data_folder/*/*_allqc.txt > $output_folder/allqc.txt

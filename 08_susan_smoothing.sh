#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      07_susan_smoothing.sh
#
# Version:          2.0
#
# Version Date:     June 21st, 2024 
#
# Version Notes:    First release
#
# Description:      Script runs susan smoothing
#                   - Calculates various values to replicate the smoothing funciton within FEAT or MELODIC
#
# Author:           Justin W. Andrushko, PhD, Vice-Chancellor Fellow & Assistant Professor, Department of Sport, Exercise and Rehabilitation, Northumbria University
#
# Intended For:     denoised functional brain imaging data after ICA filtering
#
# User Guide:       Data should be converted to nifti from DICOMS using the latest version of dcm2niix (although PAR/REC should still work).
#                   Data must be in BIDS format with the following naming convention:
#                   sub-#/ses-#/func/sub-#_bold.nii.gz
#                   sub-#/ses-#/func/sub-#_bold.json
#                   
#                   Data should have also already been run through FSLs Feat and cleaned with fsl_regfilt manually or with ICA-FIX
#
# Disclaimer:       Use scripts at own risk, the authors do not take responsibility for any errors or typos 
#                   that may exist in the scripts original or edited form.
#
# ----------------------------------------------------------------------------------------------------------------------------------------------'

#--------------------------------------#
#    Add FSL Oxford Server Specific    #
#--------------------------------------#
module add fsl

#--------------------------------------#
#          Define Directories          #
#--------------------------------------#
WDIR=/home/fs0/yzg018/scratch/pfcl_study_X # Set this to your top level BIDS formatted directory
rawdata=$WDIR/rawdata # BIDS formatted data directory
derivatives=$WDIR/derivatives # All outputs will be placed in the derivatives directory

#--------------------------------------#
#     Give read & write permissions    #
#--------------------------------------#
# chmod -R 777 $derivatives

#--------------------------------------#
#  Define Smoothing kernel size FWHM   #
#--------------------------------------#
read -p 'Enter the numeric value for your smoothing kernel [FSL recommends 5 mm (only type the number)]: ' Smoothing_fwhm
echo "You have selected a $Smoothing_fwhm mm FWHM smoothing kernel"

#--------------------------------------#
#     For Loop to Run the Script       #
#--------------------------------------#
cd $derivatives
for subject in sub-* ; do
    echo $subject
    if [ -d "$derivatives/$subject" ] ; then
        cd $derivatives/$subject
        for session in ses-* ; do
            if [ -d "$derivatives/$subject/$session" ] ; then
                cd $derivatives/$subject/$session
                feat_list=$(dirname $(find . -name "filtered_func_data_clean.nii.gz" -type f | sed 's/..//') | sort)
                for feat_path in $feat_list ; do
                    echo $feat_path
                    run_list=$(find $derivatives/$subject/$session/$feat_path -name "filtered_func_data_clean.nii.gz" -type f )
                    for run in $run_list ; do
                        if [ ! -f "$derivatives/$subject/$session/$feat_path/${run_name_noext}_smoothed.nii.gz" ] ; then
                            run_name=$(basename -- "$run")
                            echo 'Image File: '$run_name
                            run_name_noext="${run_name%%.*}"
                            smooth_sigma=$(echo "scale=15; $Smoothing_fwhm/2.35482004503" | bc)
                            Robust_intensity=$(fslstats $derivatives/$subject/$session/$feat_path/$run_name -p 2 -p 98 | awk '{print $2}')
                            temp_thresh=$(echo "scale=9; $Robust_intensity*0.1" | bc)
                            fslmaths $derivatives/$subject/$session/$feat_path/$run_name -thr $temp_thresh -Tmin -bin $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_mask.nii.gz -odt char
                            Median_brain_intensity=$(fslstats $derivatives/$subject/$session/$feat_path/$run_name -k $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_mask.nii.gz -p 50)
                            fslmaths $derivatives/$subject/$session/$feat_path/$run_name -mas $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_mask.nii.gz $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_func.nii.gz
                            fslmaths $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_func.nii.gz -Tmean $derivatives/$subject/$session/$feat_path/${run_name_noext}_mean_func.nii.gz
                            Brightness_thresh=$(echo "scale=9; $Median_brain_intensity*0.75" | bc)
                            susan $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_func.nii.gz $Brightness_thresh $smooth_sigma 3 1 1 $derivatives/$subject/$session/$feat_path/${run_name_noext}_mean_func.nii.gz $Brightness_thresh $derivatives/$subject/$session/$feat_path/${run_name_noext}_smoothed.nii.gz
                            # remove intermediate files
                            rm -r $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_func.nii.gz
                            rm -r $derivatives/$subject/$session/$feat_path/${run_name_noext}_pre_threshold_mask.nii.gz
                            rm -r $derivatives/$subject/$session/$feat_path/${run_name_noext}_mean_func.nii.gz
                            rm -r $derivatives/$subject/$session/$feat_path/${run_name_noext}*usan_size.nii.gz
                        fi
                    done
                done
            fi
        done
    fi
done                

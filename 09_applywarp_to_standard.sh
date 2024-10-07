#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      9_applywarp_to_standard.sh
#
# Version:          2.0
#
# Version Date:     June 21st, 2024 
#
# Version Notes:    None. 
#
# Description:      This script uses applywarp with prior calculated registration matrices and warp files to move subject data into standard space. This script
#                   saves outputs to a derivatives directory to better conform to the BIDS standard.
#
# Author:           Justin W. Andrushko, PhD, Vice-Chancellor Fellow & Assistant Professor, Department of Sport, Exercise and Rehabilitation, Northumbria University
#
# Intended For:     functional brain imaging data
#
# User Guide:       Data should be converted to nifti from DICOMS using the latest version of dcm2niix (although PAR/REC should still work).
#                   Data must be in BIDS format with the following naming convention:
#                   sub-#/ses-#/func/sub-#_bold.nii.gz
#                   sub-#/ses-#/func/sub-#_bold.json
#                   sub-#/ses-#/fmap/sub-#_dir-PA_epi.nii.gz
#                   sub-#/ses-#/fmap/sub-#_dir-PA_epi.json
#                   sub-#/ses-#/fmap/sub-#_dir-AP_epi.nii.gz
#                   sub-#/ses-#/fmap/sub-#_dir-AP_epi.json
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
                dir_list=$(dirname $(find . -name "filtered_func_data_clean_smoothed.nii.gz" -type f | sed 's/..//') | sort)
                for func_path in $dir_list ; do
                    echo $func_path
                    ica_dir=$(basename $func_path)        
                    echo $ica_dir
                    if [ ! -f "$derivatives/$subject/$session/$func_path/filtered_func_data_clean_smoothed_standard.nii.gz" ] ; then
                        applywarp -i $derivatives/$subject/$session/$func_path/filtered_func_data_clean_smoothed.nii.gz -o $derivatives/$subject/$session/$func_path/filtered_func_data_clean_smoothed_standard.nii.gz -r $derivatives/$subject/$session/$func_path/reg/standard.nii.gz --premat=$derivatives/$subject/$session/$func_path/reg/example_func2highres.mat -w $derivatives/$subject/$session/$func_path/reg/highres2standard_warp.nii.gz
                    else
                        echo "$ica_dir has already been registered to standard space... skipping file"
                    fi
                    echo "#-------------------------------------------------------------#"
                    echo "$ica_dir complete"
                    echo "#-------------------------------------------------------------#"
                done
            fi
        done
    fi
done
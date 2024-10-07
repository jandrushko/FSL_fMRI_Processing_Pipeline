#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      07_ica_fix.sh
#
# Version:          2.0
#
# Version Date:     June 21st, 2024 
#
# Version Notes:    None
#
# Description:      This script depends on FSL version 6.07 or higher, and runs FSL tools FIX to denoise the data.
#                   This version saves outputs to a derivatives directory to conform to the BIDS standard.
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
fix_classifier_dir=$WDIR/fix_classifier

#--------------------------------------#
# Define FIX classifier and threshold  #
#--------------------------------------#
fix_classifier="7t_pfcl_classifier"
fix_classifier_noext="${fix_classifier%.*}"
#read -p ' Specifiy your ICA FIX threshold (range 0-100, typical values are between 5-20): ' fix_threshold
fix_threshold="20"

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
                dir_list=$(dirname $(find . -name "filtered_func_data.nii.gz" -type f | sed 's/..//' | sort))
                for func_path in $dir_list ; do
                    ica_dir=$(basename $func_path)        
                    echo $ica_dir
                    # Extract ICA Features
                    if [ ! -f "$derivatives/$subject/$session/$func_path/fix/features.csv" ] ; then
                        fix -f $derivatives/$subject/$session/$func_path
                    fi
                    echo "$ica_dir feature extraction complete"
                    # Apply FIX to clean the filtered_func_data 
                    if [ ! -f "$derivatives/$subject/$session/$func_path/fix4melview_${fix_classifier_noext}_thr${fix_threshold}.txt" ] ; then
                        fix $func_path $fix_classifier_dir/${fix_classifier}.pyfix_model $fix_threshold -m 
                        echo "#-------------------------------------------------------------#"
                        echo "$ica_dir complete"
                        echo "#-------------------------------------------------------------#"
                    fi
                done
            fi
        done
    fi
done

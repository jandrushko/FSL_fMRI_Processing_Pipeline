#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      6_ic_manual_cleanup_preprocessing.sh
#
# Version:          2.0
#
# Version Date:     June 21st, 2024 
#
# Version Notes:    Version 2.0 brings updated scripting to reduce redundancies and improve script flexibility. This version now also saves
#                   outputs to a derivatives directory to better conform to the BIDS standard.
#
# Description:      Script runs ICA manual denoising
#                   - Opens fsleyes to inspect data
#                   - You must save the component labels as "hand_labels_noise.txt" 
#                   - Regresses out noise components using fsl_regfilt based on hand_labels_noise.txt info
#                   - saves denoised data as filtered_func_data_denoised.nii.gz
#
# Author:           Justin W. Andrushko, PhD, Vice-Chancellor Fellow & Assistant Professor, Department of Sport, Exercise and Rehabilitation, Northumbria University
#
# Intended For:     functional brain imaging data after ICA decomposiiton
#
# User Guide:       Data should be converted to nifti from DICOMS using the latest version of dcm2niix (although PAR/REC should still work).
#                   Data must be in BIDS format with the following naming convention:
#                   sub-#/ses-#/func/sub-#_bold.nii.gz
#                   sub-#/ses-#/func/sub-#_bold.json
#                   
#                   Data should have also already been run through FEAT or MELODIC.
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
for subject in sub-13 ; do
    echo $subject
    if [ -d "$derivatives/$subject" ] ; then
        cd $derivatives/$subject
        for session in ses-01 ; do
            if [ -d "$derivatives/$subject/$session" ] ; then
                cd $derivatives/$subject/$session
                feat_list=$(dirname $(find . -name "*filtered_func_data.nii.gz" -type f | sed 's/..//') | sort)
                anat_path=$(dirname $(find . -name "*T1w_brain.nii.gz" -type f | sed 's/..//' | sort))
                anat_file=$(find $derivatives/$subject/$session/$anat_path -name "*T1w_brain.nii.gz" -type f )
                anat_file=$(basename $anat_file)
                for feat_path in $feat_list ; do
                    if [ -f "$derivatives/$subject/$session/$feat_path/filtered_func_data.ica/hand_labels_noise.txt" ]; then
                        echo "ICA labels for" $feat_path "already exists"
                        melodicnoiseICs=($derivatives/$subject/$session/$feat_path/filtered_func_data.ica/hand_labels_noise.txt)
                        noiseICs=$(tail -1 $melodicnoiseICs)
                        noiseICs=${noiseICs#?} # removes 1st character in string
                        noiseICs=${noiseICs%?} # removes last character in string
                        # Uncomment if you want to do manual cleanup
                        # fsl_regfilt -i $derivatives/$subject/$session/$feat_path/filtered_func_data -o $derivatives/$subject/$session/$feat_path/filtered_func_data_denoised -d $derivatives/$subject/$session/$feat_path/filtered_func_data.ica/melodic_mix -f "$noiseICs"
                    else 
                        echo 'Feat directory:' $feat_path
                        echo 'Opening FSLeyes for ICA classifications'
                        fsleyes -ad --scene melodic $derivatives/$subject/$session/$feat_path/reg/highres.nii.gz -dr -35 400 $derivatives/$subject/$session/$feat_path/filtered_func_data.ica/melodic_IC.nii.gz
                        melodicnoiseICs=($derivatives/$subject/$session/$feat_path/filtered_func_data.ica/hand_labels_noise.txt)
                        noiseICs=$(tail -1 $melodicnoiseICs)
                        noiseICs=${noiseICs#?} # removes 1st character in string
                        noiseICs=${noiseICs%?} # removes last character in string
                        # Uncomment if you want to do manual cleanup
                        # fsl_regfilt -i $derivatives/$subject/$session/$feat_path/filtered_func_data -o $derivatives/$subject/$session/$feat_path/filtered_func_data_denoised -d $derivatives/$subject/$session/$feat_path/filtered_func_data.ica/melodic_mix -f "$noiseICs"
                    fi
                done
            fi
        done
    fi
done
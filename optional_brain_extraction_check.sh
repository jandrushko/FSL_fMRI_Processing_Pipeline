#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      1_anat_preprocessing.sh
#
# Version:          2
#
# Version Date:     June 20th, 2024 
#
# Version Notes:    Version 2 makes changes to check if steps have already been completed, if so then skips.
#                   Script saves outputs to a derivatives directory to conform to the BIDS standard.
#
# Description:      Script runs the following FSL tools to preprocess the T1w data
#                   - fslreorient2std
#                   - robustfov 
#                   - bet 
#                   - fast
#                   - first 
#                   - lesion_filling if a lesion mask exists
#
# Authors:          Justin W. Andrushko, PhD, Vice-Chancellor Fellow & Assistant Professor, Department of Sport, Exercise and Rehabilitation, Northumbria University
#                   Brandon J. Forys, MA, PhD Student, Department of Psychology, University of British Columbia
#
# Intended For:     T1w brain imaging data
#
# User Guide:       Data should be converted to nifti from DICOMS using the latest version of dcm2niix (although PAR/REC should still work).
#                   Data must be in BIDS format with the following naming convention:
#                   sub-#/anat/sub-#_T1w.nii.gz
#                   sub-#/anat/sub-#_T1w.json
#                   sub-#/anat/sub-#_T1w_label-lesion_roi.nii.gz <-- lesion mask if data contains lesions
#                   ---OR---
#                   sub-#/ses-#/anat/sub-#_ses-#_T1w.nii.gz
#                   sub-#/ses-#/anat/sub-#_ses-#_T1w.json
#                   sub-#/ses-#/anat/sub-#_ses-#_T1w_label-lesion_roi.nii.gz <-- lesion mask if data contains lesions
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
derivatives=$WDIR/derivatives # All outputs will be placed in the derivatives directory

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
                dir_list=$(dirname $(find . -name "*T1w.nii" -type f | sed 's/..//') | sort)
                for anat_path in $dir_list ; do
                    filename=$(basename $anat_path/*T1w.nii)
                    echo $filename
                    filename_noext="${filename%.*}"
                    fsleyes $derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented_cropped_restore -dr 35 400 $derivatives/$subject/$session/$anat_path/${filename_noext}_brain.nii.gz -dr 35 400 -cm green -a 35
                    echo "Final Step: Complete"          
                    echo "#-------------------------------------------------------------#"
                    echo "$filename preprocessing complete"
                    echo "#-------------------------------------------------------------#"
                done
            fi
        done
    fi
done

exit 0
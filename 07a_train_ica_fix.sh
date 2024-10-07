#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      07a_train_ica_fix.sh
#
# Version:          1.0
#
# Version Date:     July 15th, 2024 
#
# Version Notes:    None
#
# Description:      This script depends on FSL version 6.07 or higher, and runs FSL tools FIX to train a classifier.
#                   This version saves outputs to a derivatives directory to better conform to the BIDS standard.
#                   N.B.: hand_labels.txt MUST be saved to derivatives/sub-*/ses-*/func/sub-*_ses-*_task-*_run-*_bold.ica/filtered_func_data.ica/
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

if [ -d "$WDIR/fix_classifier" ] ; then
    fix_classifier_dir=$WDIR/fix_classifier
else
    mkdir $WDIR/fix_classifier
    fix_classifier_dir=$WDIR/fix_classifier
fi 
 
#--------------------------------------#
#      Define FIX classifier name      #
#--------------------------------------#
# read -p 'Enter a name for your new FIX classifier: ' fix_classifier
fix_classifier="7t_pfcl_classifier"

#--------------------------------------#
#     Give read & write permissions    #
#--------------------------------------#
# chmod -R 777 $derivatives

#--------------------------------------#
#     Move into derivatives folder     #
#--------------------------------------#
cd $derivatives

#-----------------------------------------------------------------------------#
#                        Create a "top" and "bottom" folder                   #
#                 top = e.g. sub-03_ses-01_task-rest_run-1_bold.ica           #  
# bottom = e.g. sub-03_ses-01_task-rest_run-1_bold.ica/filtered_func_data.ica #
#-----------------------------------------------------------------------------#
labels_dir_list_filtered_func_ica=$(find . -path "*/filtered_func_data.ica/hand_labels_noise.txt" -type f -exec dirname {} \; | sort)
labels_dir_list_top_ica=$(find $(pwd) -path "*/filtered_func_data.ica/hand_labels_noise.txt" -type f -exec dirname {} \; | xargs -n 1 dirname | sort)

#---------------------------------------------------#
#     Creates txt file with paths to top folder     #
#---------------------------------------------------#
if [ ! -f "$fix_classifier_dir/labels_path_list.txt" ] ; then
    echo  $labels_dir_list_top_ica > $fix_classifier_dir/labels_path_list.txt
fi

#------------------------------------------------#
#     Extract list of paths from created file    #
#------------------------------------------------#
labels_list=$(cat $fix_classifier_dir/labels_path_list.txt)
echo $labels_list

#--------------------------------------#
#     For Loop to Run the Script       #
#--------------------------------------#
for labels_path in $labels_dir_list_filtered_func_ica ; do
    echo $labels_path
    top_ica_dir=$(dirname $labels_path)
    echo $top_ica_dir
    if [ ! -f "$top_ica_dir/fix/features.csv" ] ; then
        fix -f $top_ica_dir # Extract features for training
    fi
    if [ ! -f "$top_ica_dir/hand_labels_noise.txt" ] ; then
        cp $labels_path/hand_labels_noise.txt $top_ica_dir/hand_labels_noise.txt
    fi    
done

#--------------------------------------#
#        Train FIX classifier          #
#--------------------------------------#
echo "Training FIX classifier"
fix -t $fix_classifier_dir/$fix_classifier -l $labels_list
echo "Training complete..."

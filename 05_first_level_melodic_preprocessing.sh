#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      05_first_level_melodic_preprocessing.sh
#
# Version:          3.0
#
# Version Date:     June 20th, 2024 
#
# Version Notes:    Version 3.0 brings updated scripting for MELODIC instead of FEAT.
#                   Outputs to a derivatives directory to better conform to the BIDS standard.
#
# Description:      Script runs first level feat preprocessing in FSL using a pre made design.fsf file
#                   - No smoothing
#                   - Motion correction
#                   - 100s High pass filter
#                   - BET is performed on the functional data
#                   - MELODIC ICA decomposition is performed
#                   - Functional data are linearly registered to native space using FLIRT with BBR
#                   - Functional data are non-linearly registered to MNI 152 Standard Space using FNIRT
#
# Author:           Justin W. Andrushko, PhD, Vice-Chancellor Fellow & Assistant Professor, Department of Sport, Exercise and Rehabilitation, Northumbria University
#
# Intended For:     functional brain imaging data
#
# User Guide:       Data should be converted to nifti from DICOMS using the latest version of dcm2niix (although PAR/REC should still work).
#                   Data must be in BIDS format with the following naming convention:
#                   sub-#/func/sub-#_bold.nii.gz
#                   sub-#/func/sub-#_bold.json
#                   ---OR---
#                   sub-#/ses-#/func/sub-#_bold.nii.gz
#                   sub-#/ses-#/func/sub-#_bold.json
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
designdir=$WDIR/first-level-processing # Location of Melodic design files

#--------------------------------------#
#     For Loop to Run the Script       #
#--------------------------------------#
cd $rawdata
for subject in sub-* ; do
    echo $subject
    if [ -d "$rawdata/$subject" ] ; then
        cd $rawdata/$subject
        for session in ses-* ; do
            if [ -d "$rawdata/$subject/$session" ] ; then
                cd $rawdata/$subject/$session
        
                dir_list=$(dirname $(find . -name "*run-1_*bold.nii" -type f | sed 's/..//'))
                anat_path=$(dirname $(find . -name "*T1w.nii" -type f | sed 's/..//'))
                anat_file=$(find $derivatives/$subject/$session/$anat_path -name "*T1w_biascorr_brain.nii.gz" -type f )
                anat_file=$(basename $anat_file)
                anat_file_noext="${anat_file%%.*}"
                anat_file_whole_head=$(find $derivatives/$subject/$session/$anat_path -name "*T1w_biascorr.nii.gz" -type f | sort)
                anat_file_whole_head_basename=$(basename $anat_file_whole_head)
                anat_file_whole_head_noext="${anat_file_whole_head_basename%%.*}"

                echo "Anat file whole head $anat_file_whole_head"
                echo "Anat file whole head_basename $anat_file_whole_head_basename"
                echo "Anat file whole head_noext $anat_file_whole_head_noext"
                echo "Anat path: $anat_path"
                echo "Anat file: $anat_file"
                rename "$anat_file_whole_head_basename" "${anat_file_whole_head_noext}_temp.nii.gz" "$anat_file_whole_head"
                
                for func_path in $dir_list ; do
                    echo "Func path: $func_path"
                    run_list=$(find $rawdata/$subject/$session/$func_path -name "*bold.nii" -type f )
                    for run in $run_list ; do               
                        filename=$(basename $run)
                        echo $filename
                        filename_noext="${filename%%.*}"
                        #mkdir -p $derivatives/$subject/$session/$func_path/
                        echo 'Image File:' $filename
                        if [ ! -d "$derivatives/$subject/$session/$func_path/${filename_noext}.ica" ] ; then
                            cp $designdir/first-level-processing.fsf $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing.fsf
                            perl -plwe 's/###SUBJECT###/'$subject'/g' $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing.fsf > $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp1.fsf
                            perl -plwe 's/###SESSION###/'$session'/g' $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp1.fsf > $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp2.fsf
                            perl -plwe 's/###ANAT_FILE###/'$anat_file'/g' $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp2.fsf > $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp3.fsf
                            perl -plwe 's/###RUN###/'$filename_noext'/g' $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp3.fsf > $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp4.fsf
                            RepTime=$(fslhd $rawdata/$subject/$session/$func_path/$filename_noext | grep -w pixdim4 | awk '{print $2}')
                            echo 'Repetition Time: '$RepTime 'seconds'
                            perl -plwe 's/###REPETITIONTIME###/'$RepTime'/g' $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp4.fsf > $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp5.fsf
                            NumberofVolumes=$(fslhd $rawdata/$subject/$session/$func_path/$filename_noext | grep -w dim4 | awk '{print $2}')
                            echo "There are" $NumberofVolumes "volumes in" $filename_noext
                            perl -plwe 's/###NVOLUMES###/'$NumberofVolumes'/g' $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp5.fsf > $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp6.fsf                 
                            perl -plwe 's/###ANAT_FILE_NOEXT###/'$anat_file_noext'/g' $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp6.fsf > $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp7.fsf
                            echo 'Running MELODIC Preprocessing'
                            feat $derivatives/$subject/$session/$func_path/${filename_noext}_first-level-processing_temp7.fsf
                            rm -r $derivatives/$subject/$session/$func_path/*.fsf
                            #rename "${anat_file_whole_head_noext}_temp.nii.gz" "$anat_file_whole_head_basename" "$derivatives/$subject/$session/$anat_path/${anat_file_whole_head_noext}_temp.nii.gz"
                            echo 'Finished Running MELODIC Preprocessing'
                        fi
                   done
                done   
            fi       
        done
    fi
done

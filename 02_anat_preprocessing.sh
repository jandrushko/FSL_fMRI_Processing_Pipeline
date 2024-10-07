#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      2_anat_preprocessing.sh
#
# Version:          3
#
# Version Date:     July 15th, 2024 
#
# Version Notes:    Version 2 makes changes to check if steps have already been completed, if so then skips.
#                   Script saves outputs to a derivatives directory to conform to the BIDS standard.
#                   Uses mri_synthstrip to brain extract
#
# Description:      Script runs the following FSL tools to preprocess the T1w data
#                   - fslreorient2std
#                   - robustfov 
#                   - bet 
#                   - fast
#                   - first 
#                   - lesion_filling if a lesion mask exists
#
#                   Script also runs the following non-FSL tools:
#                   - mri_synthstrip (https://surfer.nmr.mgh.harvard.edu/docs/synthstrip/)
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
module add freesurfer
#--------------------------------------#
#          Define Directories          #
#--------------------------------------#
WDIR=/home/fs0/yzg018/scratch/pfcl_study_X # Set this to your top level BIDS formatted directory
rawdata=$WDIR/rawdata # BIDS formatted data directory
if [ -d "$WDIR/derivatives" ] ; then
    derivatives=$WDIR/derivatives # All outputs will be placed in the derivatives directory
else
    mkdir $WDIR/derivatives
    derivatives=$WDIR/derivatives
fi
#--------------------------------------#
#     For Loop to Run the Script       #
#--------------------------------------#
cd $rawdata
for subject in sub-15 ; do
    echo $subject
    if [ -d "$rawdata/$subject" ] ; then
        cd $rawdata/$subject
        for session in ses-03 ; do
            if [ -d "$rawdata/$subject/$session" ] ; then
                cd $rawdata/$subject/$session
                dir_list=$(dirname $(find . -name "*T1w.nii" -type f | sed 's/..//') | sort)
                for anat_path in $dir_list ; do
                    filename=$(basename $anat_path/*T1w.nii)
                    echo $filename
                    filename_noext="${filename%%.*}"
                    mkdir -p $derivatives/$subject/$session/$anat_path/
                    echo "#-------------------------------------------------------------#"
                    if [ ! -f "$derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented.nii.gz" ] ; then
                        echo "Step 1: Reorienting T1w image to standard orientation"
                        fslreorient2std $rawdata/$subject/$session/$anat_path/$filename $derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented
                    else
                        echo "Step 1: Already complted... Skipping"
                    fi
                    echo "Step 1: Complete"
                    echo "#-------------------------------------------------------------#"
                    if [ ! -f "$derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented_cropped.nii.gz" ] ; then
                        echo "Step 2: Performing z-direction image cropping" # delete neck
                        robustfov -i $derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented -r $derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented_cropped
                    else
                        echo "Step 2: Already complted... Skipping"
                    fi
                    echo "Step 2: Complete"
                    echo "#-------------------------------------------------------------#"
                    if [ ! -f "$derivatives/$subject/$session/$anat_path/${filename_noext}_brain.nii.gz" ] ; then
                        echo "Step 3: Performing brain extraction with mri_synthstrip from freesurfer"
                        mri_synthstrip -i $derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented_cropped.nii.gz -o $derivatives/$subject/$session/$anat_path/${filename_noext}_brain.nii.gz --no-csf -m $derivatives/$subject/$session/$anat_path/${filename_noext}_brain_mask.nii.gz
                    fi
                    if [ ! -f "$derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain.nii.gz" ] ; then
                        # Apply bias field correction to brain extracted T1w image
                        fast -o $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain -l 20 -b -B -t 1 -I 10 -O 0 --nopve -v $derivatives/$subject/$session/$anat_path/${filename_noext}_brain
                        # Rename bias field corrected brain image from *_biascorr_brain_restore to *_biascorr_brain.nii.gz
                        mv $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain_restore.nii.gz $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain.nii.gz
                        # Use fslsmoothfill to expand the bias field outside of the brain mask 
                        fslsmoothfill -i $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain_bias.nii.gz -m $derivatives/$subject/$session/$anat_path/${filename_noext}_brain_mask.nii.gz -o $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain_bias_full -v
                        imrm $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain_bias_full_*
                        # Apply expanded bias field to the non-brain extracted T1w image (that has been reoriented and cropped)
                        fslmaths $derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented_cropped.nii.gz -div $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain_bias_full $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr.nii.gz
                        # Remove unneeded files
                        rm $derivatives/$subject/$session/$anat_path/${filename_noext}_reoriented*
                        rm $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain_seg.nii.gz
                        rm $derivatives/$subject/$session/$anat_path/${filename_noext}.nii.gz
                        rm $derivatives/$subject/$session/$anat_path/${filename_noext}_brain.nii.gz
                        # fsleyes $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr.nii.gz -dr 35 400 $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain -dr 35 400 -cm green -a 35
                        # read -p 'Are you satisfied with the quality of the brain extraction? (Y/n): ' varresponse
                        # while [[ $varresponse == "N" ]] || [[ $varresponse == "n" ]] || [[ $varresponse == "No" ]] || [[ $varresponse == "no" ]] ; do
                        #     echo "You answered $varresponse. We will now rerun brain extraction with adjusted parameters"
                        #     read -p 'Please input your desired fractional intensity threshold (0->1); default=0.5; smaller values give larger brain outline estimates: ' fractional_intensity_thresh
                        #     read -p 'Do you wish to run robust brain centre estimation (iterates BET several times)? (Y/n): ' robust_brain_centre_est
                        #     if [[ $robust_brain_centre_est == "N" ]] || [[ $robust_brain_centre_est == "n" ]] || [[ $robust_brain_centre_est == "No" ]] || [[ $robust_brain_centre_est == "no" ]] ; then
                        #         bet $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr.nii.gz $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain -f $fractional_intensity_thresh -m # add -B to bias field correct at this stage (if required)
                        #     elif [[ $robust_brain_centre_est == "Y" ]] || [[ $robust_brain_centre_est == "y" ]] || [[ $robust_brain_centre_est == "Yes" ]] || [[ $robust_brain_centre_est == "yes" ]] ; then
                        #         bet $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr.nii.gz $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain -f $fractional_intensity_thresh -R -m # add -B to bias field correct at this stage (if required)
                        #     fi
                        #     fsleyes $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr.nii.gz $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain -cm green -a 35
                        #     read -p 'Are you satisfied with the quality of the brain extraction? (Y/n): ' varresponse
                        # done
                    else
                        echo "Step 3: Already completed... Skipping"
                    fi
                    echo "Step 3: Complete"
                    echo "#-------------------------------------------------------------#"
                    if [ ! -f "$derivatives/$subject/$session/$anat_path/${filename_noext}_brain_pveseg.nii.gz" ] ; then
                        echo "Step 4: Performing tissue type segmentation"
                        fast -t 1 -n 3 -g -o $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain.nii.gz
                    else
                        echo "Step 4: Already completed... Skipping"
                    fi
                    echo "Step 4: Complete"
                    echo "#-------------------------------------------------------------#"
                    if [ ! -d "$derivatives/$subject/$session/$anat_path/first/" ] ; then
                        echo "Step 5: Performing subcortical segmentation"
                        mkdir $derivatives/$subject/$session/$anat_path/first/
                        run_first_all -b -d -i $derivatives/$subject/$session/$anat_path/${filename_noext}_biascorr_brain.nii.gz -o $derivatives/$subject/$session/$anat_path/first/${filename_noext}_biascorr_brain
                    else
                        echo "Step 5: Already completed... Skipping"
                    fi
                    echo "Step 5: Complete"
                    if [ -f "$rawdata/$subject/$session/$anat_path/*T1w_label-lesion_roi.nii.gz" ] ; then
                        lesion_mask=$(basename $rawdata/$subject/$session/$anat_path/*T1w_label-lesion_roi.nii.gz)
                        lesion_mask_noext="${lesion_mask%%.*}"
                        echo "#-------------------------------------------------------------#"
                        echo "Lesion mask detected"
                        echo "Step 6: Performing lesion filling of T1w image"
                        fslreorient2std $rawdata/$subject/$session/$anat_path/$lesion_mask $derivatives/$subject/$session/$anat_path/$lesion_mask
                        robustfov -i $derivatives/$subject/$session/$anat_path/$lesion_mask -r $derivatives/$subject/$session/$anat_path/${lesion_mask_noext}_cropped
                        rm $derivatives/$subject/$session/$anat_path/$lesion_mask
                        mv $derivatives/$subject/$session/$anat_path/${lesion_mask_noext}_cropped.nii.gz $derivatives/$subject/$session/$anat_path/$lesion_mask
                        fslmaths $derivatives/$subject/$session/$anat_path/${filename_noext}_brain_pve_2.nii.gz -thr 0.99 -bin $derivatives/$subject/$session/$anat_path/${filename_noext}_mask-wm_thr_bin.nii.gz
                        lesion_filling -c -v -w $derivatives/$subject/$session/$anat_path/${filename_noext}_mask-wm_thr_bin.nii.gz -i $derivatives/$subject/$session/$anat_path/${filename_noext}_brain.nii.gz -l $derivatives/$subject/$session/$anat_path/$lesion_mask -o $derivatives/$subject/$session/$anat_path/${filename_noext}_lesion-filled_brain.nii.gz
                        echo "Step 6: Complete"
                    fi        
                    echo "#-------------------------------------------------------------#"
                    echo "$filename preprocessing complete"
                    echo "#-------------------------------------------------------------#"
                done
            fi
        done
    fi
done
#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      1_bids_conversion.sh
#
# Version:          1
#
# Version Date:     June 20th, 2024 
#
# Version Notes:    None
#
# Description:      This script creates BIDS-compliant directories and filenames. This script assumes SIEMENS data and that fieldmaps have been collected. A different approach is required if opposite phase encoding direction 
#					images have been acquired. This script must be customised on a study-by-study basis. 
#
# Authors:          Justin W. Andrushko, PhD, Vice-Chancellor Fellow & Assistant Professor, Department of Sport, Exercise and Rehabilitation, Northumbria University
#
# Intended For:     Raw nifti and JSON files
#
# User Guide:       N/A
#
# Disclaimer:       Use scripts at own risk, the authors do not take responsibility for any errors or typos 
#                   that may exist in the scripts original or edited form.
# ----------------------------------------------------------------------------------------------------------------------------------------------'

#--------------------------------------#
#    Add FSL Oxford Server Specific    #
#--------------------------------------#
module add fsl

# Step 1: Copy things over from vols/Data/MRData/zyg018 into a directory called "sourcedata"
# Step 2: Create a new directory called "rawdata" that has all of the sourcedata in BIDS format
# Step 3: Create a new directory called "derivatives" that has all of rawdata that is processed/manipulated

# STEP 1
#mkdir -p /home/fs0/yzg018/scratch/pfcl_study_X/sourcedata
#cp -r /vols/Data/MRdata/yzg018/F7T_2023_022_070 /home/fs0/yzg018/scratch/pfcl_study_X/sourcedata #only run this if you need to copy data over from cluster into study_X/sourcedata
#cp -r /vols/Data/MRdata/yzg018/F7T_2023_022_068 /home/fs0/yzg018/scratch/pfcl_study_Y/sourcedata #only run this if you need to copy data over from cluster into study_Y/sourcedata
#cp /vols/Data/MRdata/yzg018/F7T_2023_022_062/images_06_cea_MPRAGE_UP_1mm.json /vols/Data/MRdata/yzg018/F7T_2023_022_062/images_06_cea_MPRAGE_UP_1mm.nii /home/fs0/yzg018/scratch/pfcl_study_X/sourcedata/ # to copy over individual files

sourcedata=/home/fs0/yzg018/scratch/pfcl_study_X/sourcedata
echo $sourcedata

# STEP 2
#mkdir -p /home/fs0/yzg018/scratch/pfcl_study_X/rawdata
rawdata=/home/fs0/yzg018/scratch/pfcl_study_X/rawdata
echo $rawdata
# Now you need to manually add sub-xx folders, create ses-01 folders, and add the relevant F7T_2023_022_xx files to rawdata

# STEP 3
#mkdir -p /home/fs0/yzg018/scratch/pfcl_study_X/derivatives
derivatives=/home/fs0/yzg018/scratch/pfcl_study_X/derivatives
echo $derivatives

# Now we can start messing around with BIDS
DATA=/home/fs0/yzg018/scratch/pfcl_study_X
cd $sourcedata

# TOP LOOP FOR MULTIPLE SESSIONS
for subject in sub-15 ; do
	if [ -d "$sourcedata/$subject" ] ; then
		echo "${subject}"
		cd $sourcedata/$subject
		for session in ses-03 ; do
			echo "${session}"
			cd $sourcedata/$subject/$session

			#########################################
			# MAKE BIDS DIRECTORIES
			# before running this section create participant folders (sub-01), put the relevant folders in (F7T_2023_022...), and rename them by session (ses-01)

			if [ ! -d "$rawdata/$subject/$session/extra" ] ; then
				echo "the script for pre-preprocessing all the data from" $subject $session
				mkdir -p $rawdata/$subject/$session/anat
				mkdir -p $rawdata/$subject/$session/fmap
				mkdir -p $rawdata/$subject/$session/func
				mkdir -p $rawdata/$subject/$session/mrs # name may change
				mkdir -p $rawdata/$subject/$session/extra
				echo "subdirectories created for ${subject} ${session}"
			fi

			#########################################
			# FIELDMAP

			# Change field map names (NIFTI & JSON)
			if [ ! -f "$rawdata/$subject/$session/fmap/${subject}_${session}_fmap_phasediff.nii" ] ; then
				cp $sourcedata/$subject/$session/*field_mapping_2mm_fMRI_e2_ph.nii $rawdata/$subject/$session/fmap/${subject}_${session}_fmap_phasediff.nii
				cp $sourcedata/$subject/$session/*field_mapping_2mm_fMRI_e2_ph.json $rawdata/$subject/$session/fmap/${subject}_${session}_fmap_phasediff.json
			fi

			if [ ! -f "$rawdata/$subject/$session/fmap/${subject}_${session}_fmap_magnitude1.nii" ] ; then
				cp $sourcedata/$subject/$session/*field_mapping_2mm_fMRI_e1.nii $rawdata/$subject/$session/fmap/${subject}_${session}_fmap_magnitude1.nii
				cp $sourcedata/$subject/$session/*field_mapping_2mm_fMRI_e1.json $rawdata/$subject/$session/fmap/${subject}_${session}_fmap_magnitude1.json
				echo "fmap files renamed and copied for" $subject $session
			fi			

			if [ ! -f "$rawdata/$subject/$session/fmap/${subject}_${session}_fmap_magnitude2.nii" ] ; then
				cp $sourcedata/$subject/$session/*field_mapping_2mm_fMRI_e2.nii $rawdata/$subject/$session/fmap/${subject}_${session}_fmap_magnitude2.nii
				cp $sourcedata/$subject/$session/*field_mapping_2mm_fMRI_e2.json $rawdata/$subject/$session/fmap/${subject}_${session}_fmap_magnitude2.json
				echo "fmap files renamed and copied for" $subject $session
			fi				

			#########################################
			# T1 STRUCTURAL
			
			# Change anat names (NIFTI & JSON)
			if [ ! -f "$rawdata/$subject/$session/anat/${subject}_${session}_T1w.nii" ] ; then
				echo "starting anat data for" $subject $session
				cp $sourcedata/$subject/$session/*MPRAGE*.nii $rawdata/$subject/$session/anat/${subject}_${session}_T1w.nii
				cp $sourcedata/$subject/$session/*MPRAGE*.json $rawdata/$subject/$session/anat/${subject}_${session}_T1w.json
				echo "anat files renamed and copied to rawdata" for $subject $session
			fi

			#########################################
			# fMRI

			# Change fMRI names (NIFTI & JSON)
			if [ ! -f "$rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-1_bold.nii" ] ; then
				echo "starting fmri data for" $subject $session
				cp $sourcedata/$subject/$session/*_preStim.nii $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-1_bold.nii
				cp $sourcedata/$subject/$session/*_preStim.json $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-1_bold.json
			fi
			if [ ! -f "$rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-2_bold.nii" ] ; then
				cp $sourcedata/$subject/$session/*_stim1.nii $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-2_bold.nii
				cp $sourcedata/$subject/$session/*_stim1.json $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-2_bold.json
			fi
			if [ ! -f "$rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-3_bold.nii" ] ; then
				cp $sourcedata/$subject/$session/*_stim2.nii $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-3_bold.nii
				cp $sourcedata/$subject/$session/*_stim2.json $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-3_bold.json
			fi
			if [ ! -f "$rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-4_bold.nii" ] ; then
				cp $sourcedata/$subject/$session/*_postStim.nii $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-4_bold.nii
				cp $sourcedata/$subject/$session/*_postStim.json $rawdata/$subject/$session/func/${subject}_${session}_task-rest_run-4_bold.json
				echo "fmri data renamed and copied to rawdata" $subject $session
			fi

			# MRS 
			#

		done
	fi
done
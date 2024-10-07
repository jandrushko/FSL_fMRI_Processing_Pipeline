#!/bin/bash
echo '
# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      03_prepare_fieldmaps.sh
#
# Version:          1
#
# Version Date:     July 10th, 2024
#
# Version Notes:    None
#
# Description:      This script prepares the fieldmaps for use in FEAT or MELODIC.
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
#--------------------------------------#
#          Define Directories          #
#--------------------------------------#
WDIR=/home/fs0/yzg018/scratch/pfcl_study_X # Set this to your top level BIDS formatted directory
rawdata=$WDIR/rawdata # BIDS formatted data directory
derivatives=$WDIR/derivatives

# Function to expand wildcards and store filenames in an array
expand_files() {
    local pattern="$1"
    local -n arr_ref="$2"  # Use nameref for array variable
    arr_ref=()  # Initialize the array
    for file in $pattern; do
        [ -e "$file" ] && arr_ref+=("$file")  # Check if file exists and add to array
    done
}

#--------------------------------------#
#     For Loop to Run the Script       #
#--------------------------------------#
cd $rawdata
for subject in sub-* ; do
    if [ -d "$rawdata/$subject" ] ; then
        echo $subject
        cd $rawdata/$subject
        for session in ses-03 ; do
            echo $session
            cd $rawdata/$subject/$session
            echo "Starting fieldmap prep for:" $subject $session
            fmap_dir="$rawdata/$subject/$session/fmap"
            # Expand wildcards and assign to arrays
            expand_files "$fmap_dir/*fmap_magnitude1.nii" mag1_files
            expand_files "$fmap_dir/*fmap_magnitude1.nii.gz" temp_files
            mag1_files+=("${temp_files[@]}")
            
            expand_files "$fmap_dir/*fmap_magnitude2.nii" mag2_files
            expand_files "$fmap_dir/*fmap_magnitude2.nii.gz" temp_files
            mag2_files+=("${temp_files[@]}")
            
            expand_files "$fmap_dir/*fmap_phasediff.nii" phasediff_files
            expand_files "$fmap_dir/*fmap_phasediff.nii.gz" temp_files
            phasediff_files+=("${temp_files[@]}")
            
            # Ensure all arrays have the same length
            len=${#mag1_files[@]}
            if [[ ${#mag2_files[@]} -ne $len || ${#phasediff_files[@]} -ne $len ]]; then
                echo "Error: File arrays have different lengths"
                exit 1
            fi
            
            # Loop through the files
            for ((i = 0; i < len; i++)); do
                mag1=${mag1_files[$i]}
                echo "$mag1"
                mag2=${mag2_files[$i]}
                echo "$mag2"
                phasediff=${phasediff_files[$i]}
                echo "$phasediff"
                if [ -f "$mag1" ] ; then
                    if [[ "$mag1" == *.nii.gz ]]; then
                        mag1_name=$(basename "$mag1" .nii.gz)
                        mag1_name_noext="${mag1_name%%.*}"
                        mag2_name=$(basename "$mag2" .nii.gz)
                        mag2_name_noext="${mag2_name%%.*}"
                        phasediff_name=$(basename "$phasediff" .nii.gz)
                        phasediff_name_noext="${phasediff_name%%.*}"
                    else
                        mag1_name=$(basename "$mag1" .nii)
                        mag1_name_noext="${mag1_name%.*}"
                        mag2_name=$(basename "$mag2" .nii)
                        mag2_name_noext="${mag2_name%.*}"
                        phasediff_name=$(basename "$phasediff" .nii)
                        phasediff_name_noext="${phasediff_name%.*}"
                    fi
                fi
                echo "Processing files:"
                echo "Magnitude1: $subject $session $mag1_name"
                echo "Magnitude2: $subject $session $mag2_name"
                echo "PhaseDiff: $subject $session $phasediff_name"
                # fieldmap prep and store in derivatives
                mkdir -p $derivatives/$subject/$session/fmap/
                if [ ! -f "$derivatives/$subject/$session/fmap/${subject}_${session}_fmap_rads.nii.gz" ] ; then
                    #calculate the mean of magnitude1 and magnitude2
                    fslmaths $rawdata/$subject/$session/fmap/$mag1_name -add $rawdata/$subject/$session/fmap/$mag2_name -div 2 $derivatives/$subject/$session/fmap/${subject}_${session}_fmap_mean_magnitude.nii.gz
                    #brain extract and errode
                    bet $derivatives/$subject/$session/fmap/${subject}_${session}_fmap_mean_magnitude.nii.gz $derivatives/$subject/$session/fmap/${subject}_${session}_fmap_mean_magnitude_brain.nii.gz
                    fslmaths $derivatives/$subject/$session/fmap/${subject}_${session}_fmap_mean_magnitude_brain.nii.gz -kernel boxv 3.8 -ero $derivatives/$subject/$session/fmap/${subject}_${session}_fmap_mean_magnitude_brain.nii.gz
                    #Extract TE for magnitude1 and magnitude2 from the JSON files
                    magnitude1_TE=$(awk -F ': ' '/"EchoTime"/ {gsub(/[^0-9.]/, "", $2); print $2}' $rawdata/$subject/$session/fmap/${mag1_name_noext}.json)
                    echo "Magnitude1 Echo Time: $magnitude1_TE"
                    magnitude2_TE=$(awk -F ': ' '/"EchoTime"/ {gsub(/[^0-9.]/, "", $2); print $2}' $rawdata/$subject/$session/fmap/${mag2_name_noext}.json)
                    echo "Magnitude2 Echo Time: $magnitude2_TE"
                    #calculate deltaTE (required for fsl_prepare_fieldmaps input)
                    deltaTE=$(awk -v v1=$magnitude1_TE -v v2=$magnitude2_TE 'BEGIN {print (v2 - v1) * 1000}')
                    echo "Calculated deltaTE for" $subject $session $deltaTE
                    #run fsl_prepare_fieldmaps
                    fsl_prepare_fieldmap SIEMENS $rawdata/$subject/$session/fmap/$phasediff_name $derivatives/$subject/$session/fmap/${subject}_${session}_fmap_mean_magnitude_brain.nii.gz $derivatives/$subject/$session/fmap/${subject}_${session}_fmap_rads.nii.gz $deltaTE  # 1.02 for PFCL tACS
                    echo "fielmap preparation is complete for:" $subject $session
                fi
            done
        done
    fi
done

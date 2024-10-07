#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      04_slice_timing_conversion_for_fsl.sh
#
# Version:          1.0
#
# Version Date:     June 20th, 2024 
#
# Version Notes:    None
#
# Description:      This script uses the slice timing information from the JSON file (available with SIEMENS scanners) and converts the values
#                   to fractional values of the TR. This file is then saved to the derivatives directory for use in FEAT or MELODIC.
#                   This script is also able to perform the slice timing correction using slicetimer.
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

#--------------------------------------#
#     Give read & write permissions    #
#--------------------------------------#
# chmod -R 777 $derivatives

#--------------------------------------#
#     For Loop to Run the Script       #
#--------------------------------------#
cd $rawdata
for subject in sub-* ; do
    echo $subject
    if [ -d "$rawdata/$subject" ] ; then
        cd $rawdata/$subject
        for session in ses-03 ; do
            if [ -d "$rawdata/$subject/$session" ] ; then
                cd $rawdata/$subject/$session
                dir_list=$(dirname $(find . -name "*run-1_bold.nii" -type f | sed 's/..//') | sort)
                for func_path in $dir_list ; do
                    run_list=$(find $rawdata/$subject/$session/$func_path -name "*bold.nii" -type f )
                    for run in $run_list ; do               
                        filename=$(basename $run)
                        echo $filename
                        filename_noext="${filename%.*}"

                        # Extract the slice timing array from the JSON file
                        slice_timing=$(awk '/"SliceTiming": \[/,/\]/' $rawdata/$subject/$session/$func_path/${filename_noext}.json | grep -oP '\d+\.\d+|\d+' | tr '\n' ' ')

                        # Extract repetition time
                        TR=$(awk -F ': ' '/"RepetitionTime"/ {gsub(/[^0-9]/, "", $2); print $2}' $rawdata/$subject/$session/$func_path/${filename_noext}.json)
                        echo "The TR of $filename_noext is: $TR"

                        # Calculate the adjustment factor for converting slice timing values to fractions of the TR (required for FSL slicetimer)
                        adjustment=$(echo "scale=2; $TR / 2" | bc -l)
                        # echo $adjustment

                        # Convert the slice timing to an array
                        slice_timing_array=($slice_timing)

                        # Process each value in the array
                        for i in "${!slice_timing_array[@]}"; do
                            slice_timing_array[$i]=$(echo "$adjustment - ${slice_timing_array[$i]}" | bc)
                        done

                        # Make the derivatives func directory if it does not exist
                        if [ ! -d "$derivatives/$subject/$session/$func_path" ] ; then
                            mkdir -p $derivatives/$subject/$session/$func_path
                        fi

                        # Print the processed values
                        if [ ! -f "$derivatives/$subject/$session/$func_path/${filename_noext}_relative_slice_timing_fsl.txt" ] ; then
                            for value in "${slice_timing_array[@]}"; do
                                echo $value >> $derivatives/$subject/$session/$func_path/${filename_noext}_relative_slice_timing_fsl.txt
                            done
                        else
                            echo "Slice timing file already created"
                        fi
                        #===================================================================================================================#
                        #   Uncomment below if you want to perform slice timing correction as an individual step prior to FEAT or MELODIC   #
                        #===================================================================================================================#
                        # if [ ! -f "$derivatives/$subject/$session/$func_path/${filename_noext}_st_corrected.nii.gz" ] ; then
                        #     echo "Running slice timing correction for $filename"
                        #     slicetimer -i $derivatives/$subject/$session/$func_path/$filename -o $derivatives/$subject/$session/$func_path/${filename_noext}_st_corrected -r $TR -tcustom $derivatives/$subject/$session/$func_path/${filename_noext}_relative_slice_timing_fsl.txt
                        # fi
                        echo "#-------------------------------------------------------------#"
                        echo "$filename complete"
                        echo "#-------------------------------------------------------------#"
                    done
                done
            fi
        done
    fi
done

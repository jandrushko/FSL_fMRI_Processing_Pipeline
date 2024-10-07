#!/bin/bash

echo '

# ----------------------------------------------------------------------------------------------------------------------------------------------
# Script name:      optional_motion_info.sh
#
# Version:          3.0
#
# Version Date:     July 7th, 2024 
#
# Version Notes:    None
#
# Description:      Script creates a motion summary html report
#
# Author:           Justin W. Andrushko, PhD, Vice-Chancellor Fellow & Assistant Professor, Department of Sport, Exercise and Rehabilitation, Northumbria University
#
# Intended For:     functional brain imaging data
#
# User Guide:       Data should be converted to nifti from DICOMS using the latest version of dcm2niix (although PAR/REC should still work).
#                   Data must be in BIDS format with the following naming convention:
#                   sub-#/ses-#/func/sub-#_bold.nii
#                   sub-#/ses-#/func/sub-#_bold.json
#                   sub-#/ses-#/fmap/sub-#_dir-PA_epi.nii
#                   sub-#/ses-#/fmap/sub-#_dir-PA_epi.json
#                   sub-#/ses-#/fmap/sub-#_dir-AP_epi.nii
#                   sub-#/ses-#/fmap/sub-#_dir-AP_epi.json
#
# Disclaimer:       Use scripts at own risk, the author does not take responsibility for any errors or typos 
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
# WDIR=/media/jandrush/Data/studies/PD
WDIR=/home/fs0/yzg018/scratch/pfcl_study_X # Set this to your top level BIDS formatted directory
rawdata=$WDIR/rawdata # BIDS formatted data directory
derivatives=$WDIR/derivatives # All outputs will be placed in the derivatives directory

#--------------------------------------#
# Create HTML Report File Directories  #
#--------------------------------------#
# Create the HTML report file
report_file="motion_report.html"

# Start the HTML file
echo "<html>" > $WDIR/$report_file
echo "<head><title>Subject Motion Report</title></head>" >> $WDIR/$report_file
echo "<body>" >> $WDIR/$report_file
echo "<h1>Subject Motion Report</h1>" >> $WDIR/$report_file

#--------------------------------------#
#             Run For Loop             #
#--------------------------------------#
# Loop through each subject directory in the raw data directory
for subject in "$rawdata"/sub-* ; do
    subject_name=$(basename "$subject")
    echo $subject_name
    echo "<h2>Subject: $subject_name</h2>" >> $WDIR/$report_file
    # Loop through each session directory
    for session in "$subject"/ses-* ; do
        session_name=$(basename "$session")
        echo $session_name
        echo "<h3>Session: $session_name</h3>" >> $WDIR/$report_file
        func_dir="$session/func"
        if [ -d "$func_dir" ] ; then
            # Find and process each 4D fMRI file
            for run in "$func_dir"/*bold.nii "$func_dir"/*bold.nii.gz ; do
                if [ -f "$run" ] ; then
                    if [[ "$run" == *.nii.gz ]]; then
                        run_name=$(basename "$run" .nii.gz)
                    else
                        run_name=$(basename "$run" .nii)
                    fi
                    # You can add your further processing code here
                    echo "Processing $run_name"
                    gif_file="${func_dir}/${run_name}.gif"
                    gif_file_ax="${func_dir}/${run_name}_multi-axial.gif"
                    # Convert the 4D nifti file to a series of PNG files and then to a gif
                    if [ ! -f "$gif_file" ] && [ ! -f "$gif_file_ax" ] ; then
                        fslsplit "$run" "${func_dir}/split_" -t
                        for nii_file in "${func_dir}/split_"*.nii.gz; do
                            base_name=$(basename "$nii_file" .nii.gz)
                            slicer "$nii_file" -a "${func_dir}/${base_name}_3-plane.png"
                            slicer "$nii_file" -A 750 "${func_dir}/${base_name}_multi-axial.png"
                        done
                        convert -delay 20 -loop 0 "${func_dir}/split_"*_3-plane.png "$gif_file"
                        convert -delay 20 -loop 0 "${func_dir}/split_"*multi-axial.png "$gif_file_ax"
                        # Clean up split and png files
                        rm "${func_dir}/split_"*.nii.gz
                        rm "${func_dir}/split_"*.png
                    else
                        echo $gif_file
                        echo $gif_file_ax
                    fi
                    echo "<h4>Run: ${run_name}</h4>" >> $WDIR/$report_file
                    echo "<h5>fMRI animation</h5>" >> $WDIR/$report_file
                    echo "<img src=\"$gif_file\" alt=\"${run_name} uncorrected fMRI animation\" style=\"width:800px;\" />" >> $WDIR/$report_file
                    echo "<h5>Axial multi-slice fMRI animation</h5>" >> $WDIR/$report_file
                    echo "<img src=\"$gif_file_ax\" alt=\"${run_name} uncorrected fMRI animation\" style=\"width:800px;\" />" >> $WDIR/$report_file
                    # Look for corresponding motion correction directories in derivatives
                    if [ -d "$derivatives/$subject_name/$session_name/func/${run_name}.feat" ] || [ -d "$derivatives/$subject_name/$session_name/func/${run_name}.ica" ] ; then
                        if [ -d "$derivatives/$subject_name/$session_name/func/${run_name}.feat" ] ; then
                            mc_dir="$derivatives/$subject_name/$session_name/func/${run_name}.feat"
                            echo $mc_dir
                        elif [ -d "$derivatives/$subject_name/$session_name/func/${run_name}.ica" ] ; then
                            mc_dir="$derivatives/$subject_name/$session_name/func/${run_name}.ica"
                            echo $mc_dir
                        fi
                    else
                        echo "Neither .feat nor .ica directories exist for ${subject} ${session}"
                    fi
                    if [ -d "$mc_dir/mc" ] ; then
                        fsl_motion_outliers -i $run -o $mc_dir/mc/RMS_intensity_difference_outliers -s $mc_dir/mc/RMS_intensity_difference -p $mc_dir/mc/RMS_intensity_difference --refrms --nomoco
                        fsl_motion_outliers -i $run -o $mc_dir/mc/DVARS_outliers -s $mc_dir/mc/DVARS -p $mc_dir/mc/DVARS --dvars --nomoco
                        RMS_intensity_difference_mean=$(awk '{sum+=$1} END {print sum/NR}' "$mc_dir/mc/RMS_intensity_difference")
                        RMS_intensity_difference_median=$(awk '{print $1}' "$mc_dir/mc/RMS_intensity_difference" | sort -n | awk '{a[NR]=$1} END {if (NR%2==1) {print a[(NR+1)/2]} else {print (a[(NR/2)]+a[(NR/2)+1])/2}}')
                        RMS_intensity_difference_stddev=$(awk -v mean=$RMS_intensity_difference_mean '{sum+=($1-mean)^2} END {print sqrt(sum/NR)}' "$mc_dir/mc/RMS_intensity_difference")
                        
                        dvars_mean=$(awk '{sum+=$1} END {print sum/NR}' "$mc_dir/mc/DVARS")
                        dvars_median=$(awk '{print $1}' "$mc_dir/mc/DVARS" | sort -n | awk '{a[NR]=$1} END {if (NR%2==1) {print a[(NR+1)/2]} else {print (a[(NR/2)]+a[(NR/2)+1])/2}}')
                        dvars_stddev=$(awk -v mean=$dvars_mean '{sum+=($1-mean)^2} END {print sqrt(sum/NR)}' "$mc_dir/mc/DVARS")

                        abs_mean=$(awk '{sum+=$1} END {print sum/NR}' "$mc_dir/mc/prefiltered_func_data_mcf_abs.rms")
                        abs_median=$(awk '{print $1}' "$mc_dir/mc/prefiltered_func_data_mcf_abs.rms" | sort -n | awk '{a[NR]=$1} END {if (NR%2==1) {print a[(NR+1)/2]} else {print (a[(NR/2)]+a[(NR/2)+1])/2}}')
                        abs_stddev=$(awk -v mean=$abs_mean '{sum+=($1-mean)^2} END {print sqrt(sum/NR)}' "$mc_dir/mc/prefiltered_func_data_mcf_abs.rms")

                        rel_mean=$(awk '{sum+=$1} END {print sum/NR}' "$mc_dir/mc/prefiltered_func_data_mcf_rel.rms")
                        rel_median=$(awk '{print $1}' "$mc_dir/mc/prefiltered_func_data_mcf_rel.rms" | sort -n | awk '{a[NR]=$1} END {if (NR%2==1) {print a[(NR+1)/2]} else {print (a[(NR/2)]+a[(NR/2)+1])/2}}')
                        rel_stddev=$(awk -v mean=$rel_mean '{sum+=($1-mean)^2} END {print sqrt(sum/NR)}' "$mc_dir/mc/prefiltered_func_data_mcf_rel.rms")

                        disp_img="$mc_dir/mc/disp.png"
                        rot_img="$mc_dir/mc/rot.png"
                        trans_img="$mc_dir/mc/trans.png"
                        rms_img="$mc_dir/mc/RMS_intensity_difference.png"
                        dvars_img="$mc_dir/mc/DVARS.png"
                        if [ -f "$disp_img" ] && [ -f "$rot_img" ] && [ -f "$trans_img" ] ; then
                            echo "<h4>Motion information:</h4>" >> $WDIR/$report_file
                            echo "<h5>Displacements</h5>" >> $WDIR/$report_file
                            echo "<img src=\"$disp_img\" alt=\"${run_name} Displacements Image\" style=\"width:800px;\" />" >> $WDIR/$report_file
                            echo "<h5>Rotations</h5>" >> $WDIR/$report_file
                            echo "<img src=\"$rot_img\" alt=\"${run_name} Rotations Image\" style=\"width:800px;\" />" >> $WDIR/$report_file
                            echo "<h5>Translations</h5>" >> $WDIR/$report_file
                            echo "<img src=\"$trans_img\" alt=\"${run_name} Translations Image\" style=\"width:800px;\" />" >> $WDIR/$report_file
                            echo "<h5>Root mean squared (RMS) intensity difference</h5>" >> $WDIR/$report_file
                            echo "<img src=\"$rms_img\" alt=\"${run_name} RMS Image\" style=\"width:800px;\" />" >> $WDIR/$report_file
                            echo "<h5>DVARS: Standard deviation of successive difference images</h5>" >> $WDIR/$report_file
                            echo "<img src=\"$dvars_img\" alt=\"${run_name} DVARS Image\" style=\"width:800px;\" />" >> $WDIR/$report_file
                        fi
                        absolute_motion_file="$mc_dir/mc/prefiltered_func_data_mcf_abs_mean.rms"
                        relative_motion_file="$mc_dir/mc/prefiltered_func_data_mcf_rel_mean.rms"
                        if [ -f "$absolute_motion_file" ] && [ -f "$relative_motion_file" ] ; then
                            echo "<h4>Absolute Motion Values:</h4>" >> $WDIR/$report_file
                            echo "<p>Mean: $abs_mean</p>" >> $WDIR/$report_file
                            echo "<p>Median: $abs_median</p>" >> $WDIR/$report_file
                            echo "<p>Standard Deviation: $abs_stddev</p>" >> $WDIR/$report_file
                            echo "<h4>Relative Motion Values:</h4>" >> $WDIR/$report_file
                            echo "<p>Mean: $rel_mean</p>" >> $WDIR/$report_file
                            echo "<p>Median: $rel_median</p>" >> $WDIR/$report_file
                            echo "<p>Standard Deviation: $rel_stddev</p>" >> $WDIR/$report_file
                            echo "<h4>RMS Intensity Difference Motion Values:</h4>" >> $WDIR/$report_file
                            echo "<p>Mean: $RMS_intensity_difference_mean</p>" >> $WDIR/$report_file
                            echo "<p>Median: $RMS_intensity_difference_median</p>" >> $WDIR/$report_file
                            echo "<p>Standard Deviation: $RMS_intensity_difference_stddev</p>" >> $WDIR/$report_file
                            echo "<h4>DVARS Motion Values:</h4>" >> $WDIR/$report_file
                            echo "<p>Mean: $dvars_mean</p>" >> $WDIR/$report_file
                            echo "<p>Median: $dvars_median</p>" >> $WDIR/$report_file
                            echo "<p>Standard Deviation: $dvars_stddev</p>" >> $WDIR/$report_file
                        fi
                    fi
                fi
            done
        fi
    done
done

# End the HTML file
echo "</body>" >> $WDIR/$report_file
echo "</html>" >> $WDIR/$report_file

echo "Report generated: $report_file"
echo "Report can be found in $WDIR"
echo "--------------------"
echo "You are amazing"
echo "You are worth it"
echo "You are enough"
echo "<3"
Colla
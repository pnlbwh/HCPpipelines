#!/bin/bash

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
echo -e "\n START: run_topup"

workingdir=$1

configdir=${HCPPIPEDIR_Config}
#topup_config_file=${FSLDIR}/etc/flirtsch/b02b0.cnf
topup_config_file=${configdir}/b02b0.cnf

${FSLDIR}/bin/topup --imain=${workingdir}/Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --config=${topup_config_file} --out=${workingdir}/topup_Pos_Neg_b0 -v --fout=${workingdir}/topup_Pos_Neg_b0_field.nii.gz --iout=${workingdir}/topup_Pos_Neg_b0

dimt=$(${FSLDIR}/bin/fslval ${workingdir}/Pos_b0 dim4)
dimt=$((${dimt} + 1))

# echo "Applying topup to get a hifi b0"
# ${FSLDIR}/bin/fslroi ${workingdir}/Pos_b0 ${workingdir}/Pos_b01 0 1
# ${FSLDIR}/bin/fslroi ${workingdir}/Neg_b0 ${workingdir}/Neg_b01 0 1
# ${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b01,${workingdir}/Neg_b01 --topup=${workingdir}/topup_Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --inindex=1,${dimt} --out=${workingdir}/hifib0
# 
# if [ ! -f ${workingdir}/hifib0.nii.gz ]; then
# 	echo "run_topup.sh -- ERROR -- ${FSLDIR}/bin/applytopup failed to generate ${workingdir}/hifib0.nii.gz"
# 	# Need to add mechanism whereby scripts that invoke this script (run_topup.sh)
# 	# check for a return code to determine success or failure
# fi


${FSLDIR}/bin/imrm ${workingdir}/Pos_b0*
${FSLDIR}/bin/imrm ${workingdir}/Neg_b0*
 
# echo "Running BET on the hifi b0"
# ${FSLDIR}/bin/bet ${workingdir}/hifib0 ${workingdir}/nodif_brain -m -f 0.2
 
# echo "Applying PNL invented CNN masking tool to obtain b0 brain mask"
# cnn_mask_exe=`which dwi_masking.py`
# if [ -z $cnn_mask_exe ]; then
#     echo "CNN-Diffusion-MRIBrain-Segmentation/pipeline/dwi_masking.py is not available in PATH"
#     exit 1
# fi
# 
# # TODO
# $cnn_mask_exe -i ${workingdir}/hifib0 -f $(dirname $cnn_mask_exe)/../model_folder -o ${workingdir}/nodif_brain


# define the masks in PA,AP order (pos,neg)
# obtain 107 masks
IFS=' ' read -ra masks_107 <<< $MASKS_107
${FSLDIR}/bin/applytopup --imain=${masks_107[0]},${masks_107[1]} --topup=${workingdir}/topup_Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --inindex=1,${dimt} --out=${workingdir}/mask_107 --verbose --method=jac --interp=trilinear

# obtain 99 masks
IFS=' ' read -ra masks_99 <<< $MASKS_99
${FSLDIR}/bin/applytopup --imain=${masks_99[0]},${masks_99[1]} --topup=${workingdir}/topup_Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --inindex=1,${dimt} --out=${workingdir}/mask_99 --verbose --method=jac --interp=trilinear

# take their union
pushd .
cd ${workingdir}

fslmaths mask_107 -abs mask_107
fslmaths mask_99 -abs mask_99
fslmaths mask_107 -add mask_99 nodif_brain_mask -odt char
fslmaths nodif_brain_mask -bin nodif_brain_mask

# filter the resultant mask
if [ -z `which maskfilter.py` ]; then
    echo "pnlNipype/scripts/maskfilter.py is not available in PATH"
    exit 1
fi
# maskfilter.py nodif_brain.nii.gz 2 nodif_brain.nii.gz

${FSLDIR}/bin/imrm ${workingdir}/mask_107
${FSLDIR}/bin/imrm ${workingdir}/mask_99

popd

if [ ! -f ${workingdir}/nodif_brain.nii.gz ]; then
	echo "run_topup.sh -- ERROR -- ${FSLDIR}/bin/bet failed to generate ${workingdir}/nodif_brain.nii.gz"
	# Need to add mechanism whereby scripts that invoke this script (run_topup.sh)
	# check for a return code to determine success or failure
fi

echo -e "\n END: run_topup"

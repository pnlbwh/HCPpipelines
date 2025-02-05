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

echo "Applying topup to get a hifi b0"
${FSLDIR}/bin/fslroi ${workingdir}/Pos_b0 ${workingdir}/Pos_b01 0 1
${FSLDIR}/bin/fslroi ${workingdir}/Neg_b0 ${workingdir}/Neg_b01 0 1
${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b01,${workingdir}/Neg_b01 --topup=${workingdir}/topup_Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --inindex=1,${dimt} --out=${workingdir}/hifib0

if [ ! -f ${workingdir}/hifib0.nii.gz ]; then
	echo "run_topup.sh -- ERROR -- ${FSLDIR}/bin/applytopup failed to generate ${workingdir}/hifib0.nii.gz"
	# Need to add mechanism whereby scripts that invoke this script (run_topup.sh)
	# check for a return code to determine success or failure
fi


${FSLDIR}/bin/imrm ${workingdir}/Pos_b0*
${FSLDIR}/bin/imrm ${workingdir}/Neg_b0*
 
# echo "Running BET on the hifi b0"
# ${FSLDIR}/bin/bet ${workingdir}/hifib0 ${workingdir}/nodif_brain -m -f 0.2
 
echo "Applying PNL invented CNN masking tool to obtain b0 brain mask"
cnn_mask_exe=`which dwi_masking.py`
if [ -z $cnn_mask_exe ]; then
    echo "CNN-Diffusion-MRIBrain-Segmentation/pipeline/dwi_masking.py is not available in PATH"
    exit 1
fi

pushd .
cd ${workingdir}
listpre=b0_list
realpath hifib0.nii.gz > ${listpre}.txt
$cnn_mask_exe -i ${listpre}.txt
# rename
mv hifib0_bse-multi_BrainMask.nii.gz nodif_brain_mask.nii.gz
# cleanup
rm ${listpre}*
rm *_cases_*
rm -r slicesdir_multi/
popd


if [ ! -f ${workingdir}/nodif_brain_mask.nii.gz ]; then
	echo "run_topup.sh -- ERROR -- CNN-Diffusion-MRIBrain-Segmentation/pipeline/dwi_masking.py failed to generate ${workingdir}/nodif_brain_mask.nii.gz"
	# Need to add mechanism whereby scripts that invoke this script (run_topup.sh)
	# check for a return code to determine success or failure
fi

echo -e "\n END: run_topup"

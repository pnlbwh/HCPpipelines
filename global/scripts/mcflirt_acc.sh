#!/bin/sh

#   Copyright (C) 2004-2011 University of Oxford
#
#   SHCOPYRIGHT

Usage() {
    echo ""
    echo "Usage: mcflirt_acc <4dinput> <4doutput> [ref_image]"
    echo ""
    exit
}

[ "$2" = "" ] && Usage

input=`${FSLDIR}/bin/remove_ext ${1}`
output=`${FSLDIR}/bin/remove_ext ${2}`
TR=`fslval $input pixdim4`

if [ `${FSLDIR}/bin/imtest $input` -eq 0 ];then
    echo "Input does not exist or is not in a supported format"
    exit
fi

/bin/rm -rf $output ; mkdir $output

if [ x$3 = x ] ; then
  ${FSLDIR}/bin/fslroi $input ${output}_ref 10 10
  ${FSLDIR}/bin/fslsplit ${output}_ref ${output}_tmp
  for i in `${FSLDIR}/bin/imglob ${output}_tmp????.*` ; do
      echo making reference: processing $i
      echo making reference: processing $i  >> ${output}.ecclog
      ${FSLDIR}/bin/flirt -in $i -ref ${output}_tmp0000 -nosearch -dof 6 -o $i -paddingsize 1 >> ${output}.ecclog
  done
  ${FSLDIR}/bin/fslmerge -t ${output}_ref ${output}_tmp????.*
  ${FSLDIR}/bin/fslmaths ${output}_ref -Tmean ${output}_ref
  ref=${output}_ref
else
  ref=${3}
fi

outputFile=`basename ${output}`
fslsplit $input ${output}_tmp
for i in `${FSLDIR}/bin/imglob ${output}_tmp????.*` ; do
    echo processing $i
    echo processing $i >> ${output}.ecclog
    ii=`basename $i | sed s/${outputFile}_tmp/MAT_/g`
    ${FSLDIR}/bin/flirt -in $i -ref $ref -nosearch -dof 6 -o $i -paddingsize 1 -omat ${output}/${ii}.mat >> ${output}.ecclog
    echo `${FSLDIR}/bin/avscale --allparams ${output}/${ii}.mat | grep "Rotation Angles" | awk '{print $6 " " $7 " " $8}'` `avscale --allparams ${output}/${ii}.mat | grep "Translations" | awk '{print $5 " " $6 " " $7}'` >> ${output}/mc.par
done

${FSLDIR}/bin/fslmerge -tr $output `${FSLDIR}/bin/imglob ${output}_tmp????.*` $TR

/bin/rm ${output}_tmp????.*




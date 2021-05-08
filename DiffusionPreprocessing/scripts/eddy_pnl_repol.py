#!/usr/bin/env python

import numpy as np
from conversion import read_bvals, read_bvecs, write_bvals, write_bvecs
from shutil import copyfile
REPOL_BSHELL_GREATER= 550
B0_THRESHOLD= 50
from subprocess import Popen, check_call
import sys
from plumbum import local
from os.path import join as pjoin, basename
from nibabel import load, Nifti1Image

# taken from https://github.com/pnlbwh/pnlNipype/blob/415b110edf99c13a2a70ffc2600add7231fb30ee/scripts/util.py#L34
def save_nifti(fname, data, affine, hdr=None):
    if data.dtype.name=='uint8':
        hdr.set_data_dtype('uint8')
    elif data.dtype.name=='int16':
        hdr.set_data_dtype('int16')
    else:
        hdr.set_data_dtype('float32')

    result_img = Nifti1Image(data, affine, header=hdr)
    result_img.to_filename(fname)
    

def main(): 
    
    eddy_openmp_params= sys.argv[1:]
    
    for i,arg in enumerate(eddy_openmp_params):
        if "--bvals=" in arg:
            modBvals=arg.split("--bvals=")[1]
        elif "--bvecs=" in arg:
            modBvecs=arg.split("--bvecs=")[1]
        elif "--out=" in arg:
            outPrefix=arg.split("--out=")[1]
            outPrefixInd= i
    
    bvals = np.array(read_bvals(modBvals))
    ind= [i for i in range(len(bvals)) if bvals[i]>B0_THRESHOLD and bvals[i]<= REPOL_BSHELL_GREATER]
    
    if '--repol' in eddy_openmp_params and len(ind):

        print('\nDoing eddy_openmp/cuda again without --repol option '
              'to obtain eddy correction w/o outlier replacement for b<=500 shells\n')

        eddy_openmp_params.remove('--repol')
        print(eddy_openmp_params)
        print('')
        wo_repol_outDir = local.path(outPrefix).dirname.join('wo_repol')
        wo_repol_outDir.mkdir()
        wo_repol_outPrefix = pjoin(wo_repol_outDir, basename(outPrefix))
        
        # replace --outPrefix
        eddy_openmp_params[outPrefixInd]= f'--out={wo_repol_outPrefix}'
        cmd= ' '.join(eddy_openmp_params)
        p= Popen(cmd, shell=True)
        p.wait()
        
        repol_bvecs = np.array(read_bvecs(outPrefix + '.eddy_rotated_bvecs'))
        wo_repol_bvecs = np.array(read_bvecs(wo_repol_outPrefix + '.eddy_rotated_bvecs'))

        merged_bvecs = repol_bvecs.copy()
        merged_bvecs[ind, :] = wo_repol_bvecs[ind, :]

        repol_data = load(outPrefix + '.nii.gz')
        wo_repol_data = load(wo_repol_outPrefix + '.nii.gz')
        merged_data = repol_data.get_fdata().copy()
        merged_data[..., ind] = wo_repol_data.get_fdata()[..., ind]

        save_nifti(outPrefix + '.nii.gz', merged_data, repol_data.affine, hdr=repol_data.header)

        # overwrite completely repol corrected bvecs
        write_bvecs(outPrefix + '.eddy_rotated_bvecs', merged_bvecs)
        
        # clean up
        check_call(f'rm -r {wo_repol_outDir}', shell=True)
        
        
if __name__=='__main__':
    main()



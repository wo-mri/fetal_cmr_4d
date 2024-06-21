# fetal_cmr_4d

fetal whole-heart 4D magnitude and flow cine reconstruction using multiple real-time non-coplanar balanced SSFP stacks

## Publications

__Fetal whole-heart 4D imaging using motion-corrected multi-planar real-time MRI__  
Joshua FP van Amerom, David FA Lloyd, Maria Deprez, Anthony N Price, Shaihan J Malik, Kuberan Pushparajah, Milou PM van Poppel, Mary A Rutherford, Reza Razavi, Joseph V Hajnal.  
_Magn Reson Med_. 2019; 82: 1055–1072. doi: [10.1002/mrm.27798](https://doi.org/10.1002/mrm.27798) 

__Fetal whole-heart 4D flow cine MRI using multiple non-coplanar balanced SSFP stacks__  
Thomas A. Roberts, Joshua FP van Amerom, Alena Uus, David FA Lloyd, Anthony N. Price, Jacques-Donald  Tournier, Laurence H. Jackson, Shaihan J Malik, Milou PM van Poppel, Kuberan Pushparajah, Mary A Rutherford, Reza Rezavi, Maria Deprez, Joseph V. Hajnal.
_Nature Communications_  2020; 11: 1. doi: [10.1038/s41467-020-18790-1](https://doi.org/10.1038/s41467-020-18790-1) 

## Directories

__4drecon__ - preprocessing and 4D reconstruction scripts  

__cardsync__ - cardiac synchronisation   

__eval__ - summarise and evaluate results

__lib__ - supplementary functions and external libraries

__vis__ - visualisation utilities

<!-- TODO: update installation description
## Installation

Add repository to MATLAB path.

Install MITK Workbench for viewing data and drawing masks: [mitk.org/wiki/The_Medical_Imaging_Interaction_Toolkit_(MITK)](http://mitk.org/wiki/The_Medical_Imaging_Interaction_Toolkit_(MITK)). Note, 2016.11 version is known to be stable.
 -->

<!-- TODO: add description of dependencies including SVRTK
## External Dependencies 
-->

## Framework 

This framework produces 4D magnitude cine volumes. The velocity-sensitive phase component illustrated in the figure has been removed.

**2D MRI Acquisition and Reconstruction:**
* multiple stacks of real-time non-coplanar 2D bSSFP slices and reconstructed as real-time and time-averaged images. 

**Anatomical Reconstruction:**
* an initial motion correction stage to achieve rough spatial alignment of the fetal heart using temporal mean (i.e., static) images for stack-stack registration followed by slice-volume registration interleaved with static volume (3D) reconstruction; 
* cardiac synchronisation, including heart rate estimation and slice-slice cardiac cycle alignment; and 
* further motion-correction using dynamic image frames interleaved with 4D reconstruction; and 
* 4D magnitude cine volume reconstruction, including outlier rejection.

![](4d_framework.png)  


<!-- TODO: update the steps below to reflect 

## Reconstruction Steps

The reconstruction process is performed using a combination of Matlab and bash scripts which call various C++ functions in the SVRTK toolbox. 

### Part 0 — Directory setup and MRI

Note: if using the demo dataset, Part 0 can be skipped.

1. __Setup__  \
create working directories,  \
e.g., in shell:  
	```shell 
	RECONDIR=~/path/to/recon/directory
	mkdir $RECONDIR
	mkdir $RECONDIR/data
	mkdir $RECONDIR/ktrecon
	mkdir $RECONDIR/mask
	mkdir $RECONDIR/cardsync
	```
	If using the demo dataset, then:
	```shell
	RECONDIR=~/fetal_cmr_4drecon_demo/tutorial_data
	```

2. __MRI__
    - acquire 2D multiple non-coplanar real-time MRI stacks of 2D data
    - reconstruct images using `ktrecon`,
    e.g., for each stack, in Matlab:
        ```matlab
        reconDirPath        = '~/path/to/recon/directory';
        seriesNo            = 0;
        rawDataFilePath     = '~/path/to/rawdata.lab';
        senseRefFilePath    = '~/path/to/senserefscan.lab';
        coilSurveyFilePath  = '~/path/to/coilsurveyscan.lab';
        outputDirPath       = fullfile( reconDirPath, 'ktrecon' );
        outputStr           = sprintf( 's%02i', seriesNo );
        reconOpts           = { 'GeometryCorrection', 'Yes' };

        mrecon_kt(   rawDataFilePath, ...
                    'senseref', senseRefFilePath, ...
                    'coilsurvey', coilSurveyFilePath, ...
                    'outputdir', outputDirPath, ...
                    'outputname', outputStr, ...
                    'patchversion', patchVersion,...
                    'reconoptionpairs', reconOpts )
        ```
    - further processsing
        - copy/move all magnitude-valued DC (s\*_dc_ab.nii.gz) and real-time (s\*_rlt_ab.nii.gz) files from 'ktrecon' directory to 'data' directory \
        e.g., in shell: 
            ```shell
            cp ktrecon/s*_dc_ab.nii.gz data;
            cp ktrecon/s*_rlt_ab.nii.gz data;
            ```

### 4D Magnitude CINE volume reconstruction

3. __Draw Fetal Heart Masks__
      - manually draw fetal heart masks for each `sXX_dc_ab.nii.gz` file (e.g., using the [Medical Imaging ToolKit (MITK) Workbench](http://mitk.org/wiki/Downloads#MITK_Workbench))
          - draw ROI containing fetal heart and great vessels for each slice
          - save segmentation as `sXX_mask_heart.nii.gz` segmentation in 'mask' directory

4. __Preprocessing__            
      - run `preproc` in Matlab,
          ```matlab
          reconDir = '~/path/to/recon/directory';
          S = preproc( reconDir );
          save( fullfile( reconDir, 'data', 'results.mat' ), 'S', '-v7.3' );
          ```
      - optionally, manually specify
          - target stack by changing value in 'data/tgt_stack_no.txt' (stacks are index 1,2,...)
          - excluded stacks/slices/frames by specifying in 'data/force_exclude_*.txt' (stacks/slices/frames are zero-indexed)
5. __Motion-Correction (static)__
    - create 3D mask of fetal chest
        - recon reference volume, \
        e.g., in shell: 
        ```shell
        RECONDIR=~/path/to/recon/directory
        ./recon_ref_vol.bash $RECONDIR ref_vol
        ```

6. __Draw Fetal Chest Mask__
      - draw fetal chest ROI using 'ref_vol.nii.gz' as a reference (e.g., using MITK)
      - save segmentation to 'mask' directory as  'mask_chest.nii.gz'
          - _note:_ the orientation of all later 3D/4D reconstructions is determined by this mask file; the orientation can be changed by applying a transformation to 'mask_chest.nii.gz' prior to further reconstructions

7. __Motion-Correction (static), continued__
	  - static (slice-wise) motion-correction, \
    e.g., in shell: 
        ```shell
        RECONDIR=~/path/to/recon/directory˜
        ./recon_dc_vol.bash $RECONDIR dc_vol
        ```
8. __Cardiac Intraslice Synchronisation__
    - heart-rate estimation
        - run `cardsync_intraslice`, in Matlab:
            ```matlab
            reconDir    = '~/path/to/recon/directory';
            dataDir     = fullfile( reconDir, 'data' );
            cardsyncDir = fullfile( reconDir, 'cardsync' );
            M = matfile( fullfile( dataDir, 'results.mat' ) );
            S = cardsync_intraslice( M.S, 'resultsDir', cardsyncDir, 'verbose', true );
            ```
9. __Reconstruct Slice Cine Volumes__
        - recon cine volume for each slice, \
        e.g., in shell: 
            ```shell
            RECONDIR=~/path/to/recon/directory
            ./recon_slice_cine.bash $RECONDIR
            ```
        - optionally, specify target slice by creating file 'data/tgt_slice_no.txt' containing target slice number (indexed starting at 1)

10. __Cardiac Interslice Synchronisation__
	- run `cardsync_interslice`, in Matlab:
		```matlab
		% setup
		reconDir    = '~/path/to/recon/directory';
		dataDir     = fullfile( reconDir, 'data' );
		cardsyncDir = fullfile( reconDir, 'cardsync' );
		cineDir     = fullfile( reconDir, 'slice_cine_vol' );    
		M = matfile( fullfile( cardsyncDir, 'results_cardsync_intraslice.mat' ) );

		% target slice
		tgtLoc = NaN;
		tgtLocFile = fullfile( dataDir, 'tgt_slice_no.txt' );
		if exist( tgtLocFile , 'file' )
		  fid = fopen( tgtLocFile, 'r' );
		  tgtLoc = fscanf( fid, '%f' );
		  fclose( fid );
		end

		% excluded slices
		excludeSlice = [];
		excludeSliceFile = fullfile( dataDir, 'force_exclude_slice.txt' );
		if exist( excludeSliceFile , 'file' )
		  fid = fopen( excludeSliceFile, 'r' );
		  excludeSlice = fscanf( fid, '%f' ) + 1;  % NOTE: slice locations in input file are zero-indexed
		  fclose( fid );
		end

		% slice-slice cardiac synchronisation
		S = cardsync_interslice( M.S, 'recondir', cineDir, 'resultsdir', cardsyncDir, 'tgtloc', tgtLoc, 'excludeloc', excludeSlice );
		```
11. __Motion-Correction (dynamic) & 4D Volumetric Reconstruction__
    - motion correction performed interleaved with 4D Reconstruction
    - recon 4D magnitude volume, \
	    e.g., in shell: 
	    ```shell
	    RECONDIR=~/path/to/recon/directory
	    ./recon_cine_vol.bash $RECONDIR cine_vol
	    ```

12. __Motion-Correction (dynamic) & 4D Magnitude Volumetric Reconstruction__  \
		e.g., in Matlab:  
		```matlab
		S = summarise_recon( '~/path/to/recon/directory/cine_vol', '~/path/to/recon/directory/cardsync', 'verbose', true );
		I = plot_info( '~/path/to/recon/directory/cine_vol/info.tsv');
		```
 
-->
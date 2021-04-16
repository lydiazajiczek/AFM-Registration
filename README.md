
# AFM Registration
MATLAB code for registering AFM measurement areas on thick human tissue sections using microscopy images of the whole tissue sample, microscopy images of each measurement area and processed AFM measurement data. Extracts image patches and corresponding elastic modulus data to train a GAN to infer elastic modulus from images of unstained tissue (python code [here](https://github.com/lydiazajiczek/AFM_GAN)). Also provides functionality to cluster predicted elastic modulus values for samples and estimate the underlying tissue pathology of the sample and some basic validation of the results.

## Functions
* `process_all.m`: performs user-specified processing on all liver tissue samples listed in the master `tissue_pathology.csv` file: registration, processing AFM data, extracting training patches, extracting prediction parameters and clustering, or validation.

* `registration.m`: Multi-step script that coarsely registers the location of AFM measurement sites on a whole-sample image using individual AFM FOV images and normalized cross correlation. Localizes the measurement site on each AFM FOV image using a cantilever template and determines if any rotation is necessary between AFM FOV images and whole sample image. Saves results to a workspace called `registration_results.mat` in the `fresh_images` folder of the sample being processed. Can be called by `process_all.m` or as a standalone script with user-specified variables:
  * `sample` - liver tissue sample to process, e.g. `'G159-08'` (default value)
  * `register_cantilever_rotation` - boolean flag that determines whether the cantilever needs to be registered with the AFM FOV images to roughly determine the measurement area.
  * `register_fov_rotation` - boolean flag that determines whether the relative rotation between the AFM FOV images and the whole sample image needs to be determined
  * `register_meas_sites` - boolean flag that determines whether to register each measurement site FOV with the whole-sample image
  * `i` - measurement site start index in case registration failed partway through (default 1)
  * `f1_pos` - position of figure 1 for user interaction during registration process
  * `f2_pos` - position of figure 2 for user interaction during registration process
* `process_AFM_data.m`: For a given sample, this function finds all CSV files containing processed AFM data in the expected folder location (`\<sample_folder>\AFM_measurements\`) and extracts the elastic modulus in pascals and the relative offset of the cantilever contact point to estimate the tissue topology. It saves the results in a workspace called stiffness_results.mat in the same folder. Can be called by `process_all.m` or a standalone script with user-specified variables:
  * `sample` - liver tissue sample to process, e.g. `'G159-08'` (default value)
  * `num_steps` - number of discrete steps in the AFM measurement grid (default value 8) 
* `extract_training_patches.m`: For an input sample folder containing a fresh whole sample image `Stitched.tiff`, `registration_results.mat` workspace, and `stiffness_results.mat` workspace, uses mutual information function mi_map.m to finely localize measurement area in fresh image by maximizing the mutual information between unstained image pixels and the tissue topology estimate to generate matched training pairs of microscopy image patches and elastic modulus values. Can be called by `process_all.m` or a standalone script with user-specified variables:
  * `sample` - liver tissue sample to process, e.g. `'G159-08'` (default value)
  * `size_meas_area` - physical size of the AFM measurement grid (default value 10 microns) 
  * `num_steps` - number of discrete steps in the AFM measurement grid (default value 8)
  * `search_window` - number of pixels to pad the coarsely determined measurement area by to increase the search area and account for any registration errors (default value 5 pixels) 
* `extract_parameters_and_cluster`: Extracts relevant parameters from predicted distributions of all liver tissue samples listed in the master `tissue_pathology.csv` file for the predicted whole-sample image `output_masked.tiff` located in the `AFM_predictions` sub-folder. Uses unsupervised clustering to predict tissue pathology groups and plots results in 3 dimensions for visualization. Reads tissue pathology label from master `liver_samples.csv` file. Can be called by `process_all.m` or a standalone script with no user-specified variables.
* `validation.m`: For an input sample folder containing a fresh whole sample image `Stitched.tiff`, `registration_results.mat` workspace, `stiffness_results.mat` workspace and predicted image `output_masked.tiff`, extracts elastic modulus values corresponding to actual measurement areas from the predicted image and compares them to the measured values. Can be called by `process_all.m` or a standalone script with user-specified variables:
  * `sample` - liver tissue sample to process, e.g. `'G159-08'` (default value)
  * `measurement_type` - flag to tell which time of AFM measurement area was used (read from master `liver_samples.csv` file, default value is `'normal'`) 
  * `f1_pos` - position of figure 1 for user interaction during validation process
  * `f2_pos` - position of figure 2 for user interaction during validation process
  * `plotting_each` - boolean flag to plot measured vs predicted elastic modulus of each measurement site
  * `plotting_all` - boolean flag to plot overlaid histograms of measured vs predicted elastic modulus values for all measurement sites 
  * `registration` - boolean flag to determine rotation and offset between original whole-sample images and input images to prediction network 

## Data Format
The provided functions expect the liver tissue data to be organized in the following folder hierarchy:
`samples_folder`
  * `Gxx1-xx`
    * `AFM_measurements`
      * `AFM_meas_1.map.csv`
	  * `AFM_meas_2.map.csv`
	  * ...
	  * `stiffness_results.mat` (created by `process_AFM_data.m`)
	* `AFM_predictions`
	  * ... (for prediction software see (here)[https://github.com/lydiazajiczek/AFM_GAN]) 
	  * `output_masked.tiff`
	  * `validation_results.mat` (created by `validation.m`)
	* `fresh_images`
	  * `measurement_FOVs`
	    * `AFM_meas_1-yyyymmddhhmm_RGB.tiff`
		* `AFM_meas_2-yyyymmddhhmm_RGB.tiff`
		* ...
	  * `whole_sample`
		* `Stitched.tiff`
	  * `measurement_sites.tiff` (created by `registration.m`)
	  * `registration_results.mat` (created by `registration.m`)
  * `Gxx2-xx`
  * ...

## Installation and Testing
Tested on Windows 10 with MATLAB R2019a and R2020b. Note that MATLAB can take up to an hour to install on a normal desktop computer, depending on the number of toolboxes installed.

1. Requires the following toolboxes to be installed:
    * Image Processing
    * Mapping
    * Computer Vision
    * Statistics
    * Symbolic Math
2. Requires the following MathWorks File Exchange Toolboxes to be downloaded and added to the path:
    * [inpaint_nans](https://www.mathworks.com/matlabcentral/fileexchange/4551-inpaint_nans) (c) John D'Errico
    * [Fast mutual information of two images or signals](https://www.mathworks.com/matlabcentral/fileexchange/13289-fast-mutual-information-of-two-images-or-signals) (c) Jose Delpiano
    * [Natural-Order Filename Sort](https://www.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort) (c) Stephen Cobeldick
3. Download the liver samples dataset [here](https://weiss-develop.cs.ucl.ac.uk/afm-liver-tissue-data/liver_samples.zip) and extract into a folder called `liver_samples`. Note that this dataset is 46 GB in size.
4. Change the variable `samples_path` in each of the relevant .m files to the directory location from the previous step.
5. Change the variable `path_out` in `extract_training_patches.m` to the directory location you would like to save the training patches to.
6. Choose which functions to run in `process_all.m` to process all samples, or run each .m file individually and set the sample names manually. 

A test sample is provided [here](https://weiss-develop.cs.ucl.ac.uk/afm-liver-tissue-data/test_sample.zip) with the correct outputs provided in the `test_outputs` folder for comparison.

Note that all data is provided in the sample folders such that `validation.m` can be run immediately, however running `registration.m` or `process_AFM_data.m` will overwrite existing `registration_results.mat` and `stiffness_results.mat`, for example. 

To cite this code, please use the following: 

[![DOI](https://zenodo.org/badge/346145853.svg)](https://zenodo.org/badge/latestdoi/346145853)

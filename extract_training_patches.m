%%%%%%Extract training patches%%%%%%%%%
%For an input sample folder containing a fresh whole sample image,
%registration_results.mat workspace and AFM measurement workspace 
%stiffness_results.mat, extracts scaled training patches
%uses mutual information function mi_map.m to finely localize measurement
%area in fresh image using the topology estimate

%input arguments: sample name (optional), size_meas_area (optional, 
%default 10),  num_meas_steps(optional, default 8),
%search_window (optional, default 5)
function [] = extract_training_patches(varargin)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%INPUT VALUES%%%%%%%

%%%%%%%CHANGE THIS TO PATH TO FOLDER CONTAINING ALL LIVER SAMPLES
samples_folder = 'path_to_folder_containing_liver_samples\';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%CHANGE THIS TO DESIRED PATH TO SAVE TRAINING DATA
path_out = 'path_to_folder_to_save_training_data\';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if length(varargin)==4
    size_meas_area = varargin{2};
    num_meas_steps = varargin{3};
    search_window = varargin{4}; 
elseif isempty(varargin) %set manually
    sample = 'G159-08';
    size_meas_area = 10; 
    num_meas_steps = 8;
    search_window = 5; 
else
    error('Incorrect number of input arguments.')
end

%%%%%%make folders
path_in = [samples_folder sample '\'];
if ~isfolder(path_out)
    mkdir(path_out)
end
if ~isfolder([path_out 'stiffness\'])
    mkdir([path_out 'stiffness\'])
end
if ~isfolder([path_out 'topology\'])
    mkdir([path_out 'topology\'])
end
if ~isfolder([path_out 'fresh\'])
    mkdir([path_out 'fresh\'])
end

%%%%%%parameters of AFM measurement area
AFM_step_size = size_meas_area/num_meas_steps; %in um
img_magnification = 4;
img_pixel_size = 6.5/img_magnification; %in um
AFM_scaling = 10;
fresh_scale = (img_pixel_size/AFM_step_size)*AFM_scaling;
num_pixels_AFM_scaled = num_meas_steps*AFM_scaling;
num_pixels_AFM_out = (size_meas_area/AFM_scaling)*32; 
num_pixels_fresh_out = (size_meas_area/AFM_scaling)*64;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath('utilities')
%%%%%%load registration and stiffness results for sample
reg_workspace_path = [path_in ...
                        'fresh_images\registration_results.mat'];
stiffness_workspace_path = [path_in ...
                            'AFM_measurements\stiffness_results.mat'];
lastwarn('')
load(reg_workspace_path,'meas_site_coords');
if ~isempty(lastwarn) %older registration workspace format
    load(reg_workspace_path,'fov_coords')
    meas_site_coords = fov_coords;
end
load(stiffness_workspace_path,'topology_all','stiffness_all');
img = rgb2gray(imread([path_in ...
                        'fresh_images\whole_sample\Stitched.tiff']));

%%%%%%position vector for interpolation mesh grids
col_vec = AFM_step_size:AFM_step_size:size_meas_area; %in microns
xpos = [];
ypos = [];
flag = 1;
for i=1:length(col_vec)
    if flag>0
        xpos = [xpos col_vec]; %#ok<*AGROW>
    else
        xpos = [xpos fliplr(col_vec)];
    end
    ypos = [ypos i*(AFM_step_size).*ones(1,8)];
    flag = (-1)*flag;
end
x_scaled = linspace(0,size_meas_area,num_pixels_AFM_scaled);
x_out = linspace(0,size_meas_area,num_pixels_AFM_out);
[X, Y] = meshgrid(col_vec,col_vec); %original AFM scaling
[X_scaled, Y_scaled] = meshgrid(x_scaled,x_scaled); %matched scaling
[X_out, Y_out] = meshgrid(x_out,x_out); %output scaling

%%%%%%tag structure for writing float TIFFs
tagstruct.ImageLength = num_pixels_AFM_out; %#ok<*STRNU>
tagstruct.ImageWidth = num_pixels_AFM_out; 
tagstruct.Compression = Tiff.Compression.None; 
tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP; 
tagstruct.Photometric = Tiff.Photometric.MinIsBlack; 
tagstruct.BitsPerSample = 32; 
tagstruct.SamplesPerPixel = 1; 
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;

%%%%%%loop through all measurement areas for sample
for i=1:length(meas_site_coords)
    coords = meas_site_coords{i};
    
    %%%%%%blind filenames
    fn = num2str(int64(milliseconds(datetime('now','Timezone','UTC') ...
                   - datetime('1970-01-01','Timezone','UTC'))));

    %%%%%%stiffness patches
    stiffness = inpaint_nans(stiffness_all(:,:,i)); %in Pascals
    F_s = scatteredInterpolant(X(:), Y(:), stiffness(:), 'linear');
    stiffness_final_scaled = F_s(X_out,Y_out);
    t = Tiff([path_out 'stiffness\' fn '.tiff'], 'w'); 
    t.setTag(tagstruct); 
    t.write(single(stiffness_final_scaled)); 
    t.close();

    %%%%%%topology patches
    topology = inpaint_nans(topology_all(:,:,i));
    F_t = scatteredInterpolant(X(:), Y(:), topology(:), 'linear');
     %used for coarse localization of measurement area in fresh image
    topology_scaled = F_t(X_scaled,Y_scaled);
    topology_scaled_final = F_t(X_out,Y_out);
    t = Tiff([path_out 'topology\' fn '.tiff'], 'w'); 
    t.setTag(tagstruct); 
    t.write(single(topology_scaled_final)); 
    t.close();
    
    %%%%%%fresh image
    x_min = min(coords(:,1));
    x_max = min(coords(:,1)) + ... 
            ceil(num_meas_steps*(img_pixel_size/AFM_step_size));
    y_min = min(coords(:,2));
    y_max = min(coords(:,2)) + ...
            ceil(num_meas_steps*(img_pixel_size/AFM_step_size));
    
    %extract coarsely localized measurement area + search window to account
    %for errors during registration process
    img_crop = img(x_min-search_window:x_max+search_window, ...
                   y_min-search_window:y_max+search_window);
    
    %in case localization is on edge of search area, find larger image
    %output image will be twice the size of the measurement area (64x64)
    img_crop_exp = img(x_min-4*search_window:x_max+4*search_window, ...
                       y_min-4*search_window:y_max+4*search_window);
    
    %upscale and enhance contrast
    img_crop_scaled = imresize(img_crop,fresh_scale);
    img_crop_scaled_large = imresize(img_crop_exp,fresh_scale);
    offset_y = floor((size(img_crop_scaled_large,1) - ...
                      size(img_crop_scaled,1))/2);
    offset_x = floor((size(img_crop_scaled_large,2) - ...
                      size(img_crop_scaled,2))/2);
    img_contrast = adapthisteq(img_crop_scaled);
    img_contrast_large = adapthisteq(img_crop_scaled_large);
    
    %use mutual information to finely localize measurement area using
    %topology map
    disp(['extracting fresh image for meas site ' num2str(i) ' of ' ...
          num2str(length(meas_site_coords))])
    m = mi_map(topology_scaled,img_contrast);
    [j,k] = find(m==max(max(m)));
    j_i = min(j)-num_pixels_AFM_scaled/2+offset_y;
    j_f = max(j)+num_pixels_AFM_scaled/2+offset_y;
    k_i = min(k)-num_pixels_AFM_scaled/2+offset_x;
    k_f = max(k)+num_pixels_AFM_scaled/2+offset_x;
    img_fresh_area = img_contrast_large(j_i:j_f,k_i:k_f);
    img_fresh_final = imresize(img_fresh_area, ...
                      [num_pixels_fresh_out, num_pixels_fresh_out]);
    imwrite(img_fresh_final,[path_out 'fresh\' fn '.tiff'])
end

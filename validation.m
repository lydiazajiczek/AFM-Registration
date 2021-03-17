%%%%%%Validate with measurements%%%%%%%%%
%For an input sample folder containing a fresh whole sample image,
%registration_results.mat workspace, AFM measurement workspace 
%stiffness_results.mat and predicted image, extracts the measurement areas
%from the predicted image and compares it to the actual measured values

%input arguments: sample name (optional, can specify manually in script)
%measurement_type (default normal), figure 1 position, figure 2 position,
%plotting_each (default false), plotting_all (default true), 
%registration (default true)
function [] = validation(varargin)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%INPUT VALUES%%%%%%%

%%%%%%%CHANGE THIS TO PATH TO FOLDER CONTAINING ALL LIVER SAMPLES
samples_folder = 'path_to_folder_containing_liver_samples\'; 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isempty(varargin)
    sample = 'G159-08';
    measurement_type = 'normal';
    %%%%%%flags
    plotting_each = false;
    plotting_all = true;
    registration = true;
    if registration
        close all
        f1 = figure;
        f2 = figure;
        prompt = ['Please dock figures where you can see both easily,' ...
                    'and press ENTER when you are finished: '];
        y = input(prompt); %#ok<*NASGU>
        f1_pos = get(f1,'Position');
        f2_pos = get(f2,'Position'); 
    end
elseif length(varargin) == 7
    sample = varargin{1};
    measurement_type = varargin{2};
    f1_pos = varargin{3};
    f2_pos = varargin{4};
    plotting_each = varargin{5};
    plotting_all = varargin{6};
    registration = varargin{7};
else
    error('Incorrect number of input arguments')
end
min_EM = 0;
max_EM = 2000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath('utilities')
%%%%%%build paths and load workspaces
path_in = [samples_folder sample '\'];
path_fresh = [path_in 'fresh_images\'];
path_AFM_meas = [path_in 'AFM_measurements\'];
path_AFM_pred = [path_in 'AFM_predictions\'];
reg_workspace_path = [path_fresh 'registration_results.mat'];
val_workspace_path = [path_AFM_pred 'validation_results.mat'];

lastwarn('')
load(reg_workspace_path,'meas_site_coords');
if ~isempty(lastwarn) %older registration workspace format
    load(reg_workspace_path,'fov_coords')
    meas_site_coords = fov_coords;
end
stiffness_workspace_path = [path_AFM_meas 'stiffness_results.mat'];
load(stiffness_workspace_path,'stiffness_all')

%%%%%%parameters of AFM measurement area
switch measurement_type
    case 'normal'
        size_meas_area = 10; %in um
        num_meas_steps = 8;
        search_window = 5;
    case 'large'
        size_meas_area = 20; %in um
        num_meas_steps = 12;
        search_window = 6;
end
AFM_step_size = size_meas_area/num_meas_steps; %in um
img_magnification = 4;
img_pixel_size = 6.5/img_magnification; %in um

%%%%%%load images to find rotation and offset
if registration
    original_image = rgb2gray(imread([path_fresh ...
                     'whole_sample\Stitched.tiff']));
    try
        input_image = rgb2gray(imread([path_AFM_pred ...
                     'input.tiff']));
    catch
        input_image = imread([path_AFM_pred ...
                      'input.tiff']);
    end
    [~,theta,~,~] = feature_based_rotation(input_image, ...
                        original_image,f1_pos,f2_pos);
    input_image_rot = imrotate(input_image,-theta);
    idx = input_image_rot == 0;
    input_image_rot(idx) = 255; %to match background
    [~,offset_coordinates,~] = cross_corr_and_overlay(input_image_rot, ...
                                                    original_image,false);
    save(val_workspace_path,'theta','offset_coordinates');
else
    load(val_workspace_path,'theta','offset_coordinates')
end
prediction = imrotate(imread([path_AFM_pred 'output.tiff']),-theta);
    
%%%%%%load all measurement sites and extract predicted stiffness
%%%%%%(coarsely registered)
for i=1:length(meas_site_coords)
    coords = meas_site_coords{i};
    y_min = min(coords(:,1)) - offset_coordinates(3);
    y_max = y_min + ceil(num_meas_steps*(AFM_step_size/img_pixel_size));
    x_min = min(coords(:,2)) - offset_coordinates(1);
    x_max = x_min + ceil(num_meas_steps*(AFM_step_size/img_pixel_size));
    stiffness_pred(:,:,i) = prediction(y_min - search_window:y_max ...
        + search_window, x_min - search_window:x_max + ...
        search_window); %#ok<*AGROW>
    stiffness_meas = stiffness_all(:,:,i);
    if plotting_each
        figure
        subplot(1,2,1)
        imagesc(stiffness_meas,[min_EM max_EM])
        colormap hot
        shading interp
        colorbar
        axis square
        title('Measured')
        subplot(1,2,2)
        imagesc(stiffness_pred(:,:,i),[min_EM max_EM])
        colormap hot
        shading interp
        colorbar
        axis square
        title('Predicted')
    end
end
save(val_workspace_path,'theta','offset_coordinates','-append');
%%%%%%plot comparison of measured and inferred EM values for sample
figure
[~,edges] = histcounts(stiffness_all,num_meas_steps^2, ...
            'BinLimits',[min_EM max_EM]);
histogram(stiffness_all,num_meas_steps^2, ...
            'BinLimits',[min_EM max_EM], ...
            'Normalization','probability')
hold on
histogram(stiffness_pred,edges,'Normalization','probability')
xlabel('Elastic Modulus (Pa')
ylabel('Probability')
legend('Measured','Predicted')
title(sample)
axis square
saveas(gcf,[path_AFM_pred 'comparison_histogram.png']) 
prompt = 'Press ENTER when you are finished.';
y = input(prompt);
close all
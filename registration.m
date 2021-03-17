%%%%%%Registration%%%%%%%%%
%Multi-step script that coarsely registers the location of AFM measurement
%sites on a whole-sample image using individual AFM FOV images and
%normalized cross correlation. Localizes the measurement site on each AFM
%FOV using a cantilever template and determines if any rotation is
%necessary between AFM FOV images and whole sample image. Saves results to
%workspace called registration_results.mat.

%inputs: sample to process (optional), register_cantilever_rotation
%boolean flag (optional), register_fov_rotation boolean flag (optional),
%register_meas_sites boolean flag (optional), start index i (optional)
%f1_pos and f2_pos: positions of figures for user interaction during
%registration process
function [] = registration(varargin)
close all
warning('off','images:initSize:adjustingMag');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%INPUTS%

%%%%%%%CHANGE THIS TO PATH TO FOLDER CONTAINING ALL LIVER SAMPLES
samples_folder = 'path_to_folder_containing_liver_samples\';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if length(varargin) == 7
    %%%%%%Sample name
    sample = varargin{1}; 
    %%%%%%Optional flags to choose which parts of 
    %%%%%%registration process to carry out
    register_cantilever_rotation = varargin{2};
    register_fov_rotation = varargin{3};
    register_meas_sites = varargin{4};
    %%%%%%Index of AFM measurement site to start with if 
    %%%%%%registration failed part way through
    i = varargin{5};
    f1_pos = varargin{6};
    f2_pos = varargin{7};
elseif isempty(varargin) %set manually
    sample = 'G159-08';
    register_cantilever_rotation = false;
    register_fov_rotation = false;
    register_meas_sites = true;
    i = 1; 
else
    error('Incorrect number of input arguments')
end
images_path = [samples_folder sample '\fresh_images\'];

%%%%%%Image metadata (should not change)
fresh_mag = 4;
%default, but checks filename in case only a 10X image was captured
fov_mag = 4; %#ok<*NASGU> 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%set up figure windows for user interaction
if and(isempty(varargin),any([register_cantilever_rotation, ...
                              register_fov_rotation,register_meas_sites]))
    f1 = figure;
    f2 = figure;
    prompt = ['Please dock figures where you can see both easily, ' ...
              'and press ENTER when you are finished: '];
    y = input(prompt);
    f1_pos = get(f1,'Position');
    f2_pos = get(f2,'Position');
    close all
end

addpath('utilities')
%%%%%%load cantilever template data
load('utilities\bead_coords.mat','bead_coords_crop');
workspace_path = [images_path 'registration_results.mat'];

%%%%%%load stitched whole-sample fresh image
fresh_img_path = [images_path 'whole_sample\Stitched.tiff'];
try
    fresh_img = rgb2gray(imread(fresh_img_path));
catch
    fresh_img = imread(fresh_img_path);
end

%%%%%%get all measurement FOV filepaths
fovs_path = [images_path 'measurement_FOVs\'];
folder_info = dir(fovs_path);
fn_list = extractfield(folder_info,'name');
if any([register_meas_sites,register_cantilever_rotation, ...
        register_fov_rotation])
    idx = contains(fn_list,'_RGB.tiff');
    fov_fns = fn_list(idx);
    fov_list = cell(length(fov_fns),2);
    for j=1:length(fov_fns)
        fn = fov_fns{j};
        fov_name = split(fn,'-');
        fov_no = regexp(fov_name{1},'\d*','Match');
        fov_list{j,1} = fn;
        fov_list{j,2} = str2double(fov_no{1});
    end
    fov_list = sortrows(fov_list,2);
    fov_fns = fov_list(:,1); %sorted filename list
end

%%%%%%find location of bead/measurement area on AFM FOV (will be the same
%%%%%%for all AFM FOV images in folder since camera was fixed during scan)
if register_cantilever_rotation
    cant_mask = double(imfill(imread(['utilities\' ...
                       'cantilever_template_mask.tiff'])<128,'holes'));
    cant_img = rgb2gray(imread(['utilities\' ...
                       'cantilever_template.tiff'])); 
    cant_img_scan = double(imread(['utilities\' ...
                                   'cantilever_template_scan.tiff']));
    %pixels where AFM scan takes place are set to zero in template image
    idx = cant_img_scan == 0; 
    cant_img_scan(idx)= -1; %for localizing scan area
    fov_img = rgb2gray(imread([fovs_path fov_fns{1}]));
    correct_thresh = false;
    correct_theta = false;
    f1 = imshow(cant_mask,[]);
    set(gcf,'Position',f1_pos);
    figure
    f2 = imshow(double(fov_img),[]);
    set(gcf,'Position',f2_pos);
    %%%%%%Get user to set threshold value for feature-based rotation using
    %%%%%%cantilever template image and AFM FOV
    while ~correct_thresh
        [threshold, correct_thresh] = set_threshold(fov_img,f2);
    end
    close figure 1
    error_count = 0;
    cant_theta = 0;
    while ~correct_theta
        if error_count == 2
            %try other FOV images in folder if not working
            fov_img = rgb2gray(imread([fovs_path fov_fns(2)]));
        elseif error_count == 4
            fov_img = rgb2gray(imread([fovs_path fov_fns(3)]));
        elseif error_count >= 6
            %manual rotation as last resort
            prompt = 'Enter rotation angle in degrees: '; 
            cant_theta = str2double(input(prompt,'s'));
        end
        try 
            fov_img_thresh = double(fov_img<threshold);
            if error_count <6
                %print theta for user verification
                [~,cant_theta,~,~] = feature_based_rotation(cant_mask, ...
                fov_img_thresh,f1_pos,f2) %#ok<NOPRT> 
            end
        catch
            disp('Not enough points for feature based matching.')
        end
        cant_img_rot = imrotate(cant_mask,-cant_theta);
        [fov_overlay,cant_coords,~,cant_crop_coords,~] = ...
                cross_corr_and_overlay(cant_img_rot,fov_img_thresh, ...
                                       false,f1_pos,f2);
        set(f2,'CData',fov_overlay);
        prompt = 'Is this rotation angle correct? Answer Y/N: ';
        user_input = input(prompt,'s');
        if all(upper(user_input) == 'Y')
            close all
            %overlay cantilever template with scan area pixels set to -1
            correct_theta = true;
            cant_scan_rot = imrotate(cant_img_scan,-cant_theta);
            cant_scan_crop = imcrop(cant_scan_rot,cant_crop_coords);
            fov_scan = double(fov_img);
            fov_scan(cant_coords(3):cant_coords(4), ...
                     cant_coords(1):cant_coords(2)) = cant_scan_crop;
        else
            correct_thresh = false;
            error_count = error_count + 1;
            while ~correct_thresh
                [threshold, correct_thresh] = set_threshold(fov_img,f2);
            end
        end
        
    end
    %%%%%%save as you go
    save(workspace_path,'threshold','fov_scan');
else
    load(workspace_path,'fov_scan');
end

close all

%%%%%%find rotation of FOVs relative to whole sample image 
%%%%%%using feature based matching
if register_fov_rotation
    correct_theta = false;
    rot_fov_theta = 0;
    error_count = 0;
    fov_img = rgb2gray(imread([fovs_path fov_fns{1}]));
    imshow(fov_img);
    set(gcf,'Position',f1_pos);
    figure(2)
    f2 = imshow(fresh_img);
    set(gcf,'Position',f2_pos);
    while ~correct_theta
        if error_count == 1
            %try other FOV images in folder if not working
            fov_img = rgb2gray(imread([fovs_path fov_fns{2}]));
        elseif error_count == 2
            fov_img = rgb2gray(imread([fovs_path fov_fns{3}]));
        elseif error_count >= 3
            %manual rotation as last resort
            prompt = 'Enter rotation angle in degrees: ';
            rot_fov_theta = str2double(input(prompt,'s'));
            fov_crop = fov_img;
        end
        try 
            if error_count < 3
                [~,rot_fov_theta,fov_crop] = ...
                    feature_based_rotation(fov_img,fresh_img,f1_pos,f2);
            end
        catch
            disp('Not enough points for feature based matching.')
        end
        disp(['Rotation angle: ' num2str(rot_fov_theta) ' deg'])
        rot_fov_img = imrotate(fov_crop,-rot_fov_theta);
        prompt = 'Does this angle look correct? Y/N: ';
        user_input = input(prompt,'s');
        if all(upper(user_input) == 'Y')
            close figure 1
            %%%%%%overlay for user to verify
            [fresh_overlay,coords,~,~,~] = ...
                cross_corr_and_overlay(rot_fov_img,fresh_img,false, ...
                                       f1_pos,f2);
            set(f2,'CData',fresh_overlay)
            validate_rect = imrect(gca, [coords(1), coords(3), ...
                            coords(2)-coords(1), coords(4)-coords(3)]);
            prompt = 'Is this rotation correct? Y/N: ';
            user_input = input(prompt,'s');
            if all(upper(user_input) == 'Y')
                correct_theta = true; 
            else
                error_count = error_count+1;
                close figure 1
                figure(1)
                imshow(fov_img)
                validate_rect.delete;
            end
        else
            error_count = error_count+1;
            close figure 1
            figure(1)
            imshow(fov_img)
        end
    end
    validate_rect.delete;
    fov_scan_rot = imrotate(fov_scan,-rot_fov_theta);
    %%%%%%save as you go
    save(workspace_path,'rot_fov_theta','fov_scan_rot','-append');
else
    load(workspace_path,'rot_fov_theta','fov_scan_rot')
end

close all

%%%%%%%%%%%%loop through AFM FOVs to coarsely register scan location on 
%%%%%%%%%%%%whole sample image
%preallocate structures for measurement site coordinates and labels
meas_site_coords = cell(size(fov_fns)); 
label_str = cell(size(fov_fns)); 
position = zeros(length(fov_fns),4); 
if i~=1 %registration must have died so start partway through
    load(workspace_path,'meas_site_coords')
end
fov_img = rgb2gray(imread([fovs_path fov_fns{1}]));
fov_img_rot = imrotate(fov_img,-rot_fov_theta);
f1 = imshow(fov_img_rot);
set(gcf,'Position',f1_pos);
figure(2)
f2 = imshow(fresh_img);
set(gcf,'Position',f2_pos);
while i<=length(fov_fns)
	fov_img = rgb2gray(imread([fovs_path fov_fns{i}]));
	if strfind(fov_fns{i},'10X')
        %in rare cases only 10X image was captured for FOV
		fov_mag = 10; 
		scale_factor_fov = fov_mag/fresh_mag;
		fov_img = imresize(fov_img,1/scale_factor_fov,'bilinear');
		fov_scan_rot_10 = imresize(fov_scan_rot, ...
                                   1/scale_factor_fov,'bilinear');
	end
	fov_img_rot = imrotate(fov_img,-rot_fov_theta);
	set(f1,'CData',fov_img_rot);
	set(f2,'CData',fresh_img);
    
	%%%%%%load AFM FOV and let the user know which FOV is being loaded
	%%%%%%then crop AFM FOV to remove cantilever structure which affects
	%%%%%%registration accuracy
	disp(fov_fns{i}) 
	[fresh_overlay,overlay_coords,~,fov_crop_coords] = ...
                cross_corr_and_overlay(fov_img_rot,fresh_img,false,f1,f2); 
	if strfind(fov_fns{i},'10X')
		fov_scan_crop = imcrop(fov_scan_rot_10,fov_crop_coords);
    else
        %Note: expects scan site to be in cropped image
		fov_scan_crop = imcrop(fov_scan_rot,fov_crop_coords); 
	end
	set(f2,'CData',fresh_overlay)
	valid_rect = imrect(gca,[overlay_coords(1),overlay_coords(3), ...
                            size(fov_scan_crop,2),size(fov_scan_crop,1)]);
	prompt = 'Is this correct? Answer Y/N: ';
	user_input = input(prompt,'s');
	if all(upper(user_input) == 'Y')
		%now assign scan fov image to locate scan area on large image
		fresh_img_scan = double(fresh_img);
		fresh_img_scan(overlay_coords(3):overlay_coords(4), ...
            overlay_coords(1):overlay_coords(2)) = fov_scan_crop;
		[j,k] = find(fresh_img_scan==-1);
		meas_site_coords{i} = [j,k];
        %rough estimate of measurement area (just for visualization)
		position(i,:) = [min(k) min(j) 12 12]; 
		label_str{i} = num2str(i); 
		i = i+1;
        save(workspace_path,'meas_site_coords','-append'); %save as you go
	end
	valid_rect.delete;
end
save(workspace_path,'meas_site_coords','-append');

%%%%%%%%create and save annotated image showing coarsely registered
%%%%%%%%measurement sites for visualization purposes
overlay_annotated = insertObjectAnnotation(fresh_img,'rectangle', ...
                    position,label_str,'TextBoxOpacity',0.9,'FontSize',72);
close figure 1
figure(1)
figure('units','normalized','outerposition',[0 0 1 1])
imshow(overlay_annotated)
saveas(gcf,[images_path 'measurement_sites.tiff'])

close all

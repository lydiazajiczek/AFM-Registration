%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%process_all.m
%script to process all samples using tissue_pathology.csv master file
%user selects which processing function to carry out
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%CHANGE THIS TO PATH TO FOLDER CONTAINING ALL LIVER SAMPLES
samples_folder = 'path_to_folder_containing_liver_samples\';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

T = readtable([samples_folder 'tissue_pathology.csv']);
sample_list_all = T.Sample;
measurement_type = T.AFM_Measurement_Type;

%%%%%%which processing to carry out
registration_flag = false;
process_AFM_data_flag = false;
extract_training_patches_flag = false;
extract_parameters_and_cluster_flag = false;
validation_flag = false;

warning('off','images:initSize:adjustingMag');
%%%%%%modify figures for user interaction with figures
if any([registration_flag,validation_flag])
    close all
    f1 = figure;
    f2 = figure;
    prompt = ['Please dock figures where you can see both easily, ' ...
             'and press ENTER when you are finished: '];
    y = input(prompt);
    f1_pos = get(f1,'Position');
    f2_pos = get(f2,'Position');
end

for i=1:length(sample_list_all)

    %%%%%%set parameters of AFM measurement area
    switch measurement_type{i}
        case 'normal'
            size_meas_area = 10; %in um
            num_meas_steps = 8;
            search_window_size = 5;
        case 'large'
            size_meas_area = 20; %in um
            num_meas_steps = 12;
            search_window_size = 6;
    end
        
    if registration_flag
        %%%%%%registration(sample,register_cantilever_rotation,
        %%%%%%register_fov_rotation,register_meas_sites,start_index)
        registration(sample_list_all{i},true,true,true,1,f1_pos,f2_pos)
    end
    
    if process_AFM_data_flag
        %%%%%%process_AFM_data(sample,num_steps)
        process_AFM_data(sample_list_all{i},num_meas_steps)
    end

    if extract_training_patches_flag
        %%%%%%extract_training_patches(sample, size_meas_area, 
        %%%%%%num_meas_steps, search_window_size)
        extract_training_patches(sample_list_all{i},size_meas_area, ...
                                 num_meas_steps,search_window_size)
    end
    
    if extract_parameters_and_cluster_flag
        %%%%%%no input arguments
        extract_parameters_and_cluster
    end

    if validation_flag
        %%%%%%validation(sample,measurement_type,f1_pos,f2_pos,
        %%%%%%plotting_each,plotting_all,registration)
        validation(sample_list_all{i},measurement_type{i}, ... 
                   f1_pos,f2_pos,false,true,false)
    end
    
end
%%%%%%Process AFM Data%%%%%%%%%
%For a given sample, finds all CSV files in the expected folder location
%and extracts the elastic modulus in pascals and the relative offset of the
%cantilever contact point to estimate  tissue topology

%input arguments: sample name (optional), num_steps (optional,
%default 8 for normal AFM measurement area size)
%saves results in a workspace called stiffness_results.mat
function [] = process_AFM_data(varargin)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%INPUT VALUES%

%%%%%%%CHANGE THIS TO PATH TO FOLDER CONTAINING ALL LIVER SAMPLES
samples_folder = 'path_to_folder_containing_liver_samples\'; 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isempty(varargin)
    sample = 'G159-08';
	num_steps = 8;
elseif length(varargin)==2
    sample = varargin{1};
	num_steps = varargin{2};
else
	error('Incorrect number of additional input arguments')
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%get filename list
path_in = [samples_folder sample '\AFM_measurements\'];
file_list = dir(path_in);
filenames = extractfield(file_list,'name');
idx = endsWith(filenames,'.csv');
file_list = natsortfiles(filenames(idx));
num_meas = length(file_list);

%%%%%%%preallocate
stiffness_all = zeros(num_steps,num_steps,num_meas);
topology_all = zeros(num_steps,num_steps,num_meas);

for i=1:num_meas
    disp([path_in file_list{i}])
    T = importdata([path_in file_list{i}]);
    stiffness_full = nan(num_steps^2,1);
    topology_full = nan(num_steps^2,1);
    pos = T.data(:,1)+1; %position number vector (unsorted)
    stiffness = T.data(:,7); %stiffness vector in Pa (unsorted)
    contact_pt_offset = T.data(:,6); %contact point offset (in m)
    contact_pt_offset = contact_pt_offset - mean(contact_pt_offset);
    %sorted by position numbers
    all_vals = sortrows([pos stiffness contact_pt_offset]); 
    idx = all_vals(:,1);
    stiffness_full(idx) = all_vals(:,2);
    topology_full(idx) = all_vals(:,3);
    stiffness_mat = reshape(stiffness_full,[num_steps num_steps]);
    topology_mat = reshape(topology_full,[num_steps num_steps]);
    for j=1:uint16(num_steps/2)
        stiffness_mat(:,2*j) = flipud(stiffness_mat(:,2*j));
        topology_mat(:,2*j) = flipud(topology_mat(:,2*j));
    end
    stiffness_all(:,:,i) = stiffness_mat; 
    topology_all(:,:,i) = topology_mat;
end

%%%%%%save results
workspace_path = [path_in 'stiffness_results.mat'];
save(workspace_path,'stiffness_all','topology_all');
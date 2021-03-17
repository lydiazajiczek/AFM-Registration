%%%%%%Mutual information map%%%%%%%%%
%For an input query and template image, this function calculates the mutual
%information between them. It returns a map the same size as the template
%image with the mutual information of the template image with the query
%image overlaid at each point (similar to cross correlation)

%Uses the function mi.m from "Fast mutual information of two images or 
%signals" by Jose Delpiano (https://www.mathworks.com/matlabcentral/
%fileexchange/13289-fast-mutual-information-of-two-images-or-signals), 
%MATLAB Central File Exchange.

%inputs: query image, template image, measurement site number (optional)
%and total number of measurement sites (optional) if the user wishes to 
%have the estimated time remaining displayed on screen

%outputs: the mutual information map mi_map (same size as template)

function mi_map = mi_map(query,template,varargin)

if isempty(varargin)
    display_time = false;
elseif length(varargin)==2
    display_time = true;
    meas_site = varargin{1}; %#ok<*NASGU>
    num_sites = varargin{2}; 
else
    error(['Incorrect number of additional input arguments: ' ...
           'needs meas_site, num_sites'])
end

mi_map = zeros(size(template));
[nx_t,ny_t] = size(template);
[nx_q,ny_q] = size(query);
num_x_steps = floor(nx_t/nx_q) - 1; 
num_y_steps = floor(ny_t/ny_q) - 1;
step = 1;
mi_fun = @(block_struct) mi(block_struct.data,query)*ones(size(query));

for ii=0:step:nx_q-1
    for jj=0:step:ny_q-1
        tic
        template_sub = template((1+ii):(num_x_steps*nx_q+ii), ...
                                (1+jj):(num_y_steps*ny_q+jj));
        mi_temp = blockproc(template_sub,size(query),mi_fun, ...
                            'UseParallel',true,'DisplayWaitBar',false);
        mi_map((1+ii):(num_x_steps*nx_q+ii), ...
               (1+jj):(num_y_steps*ny_q+jj)) =  ...
               max(mi_temp,mi_map((1+ii):(num_x_steps*nx_q+ii), ...
                                  (1+jj):(num_y_steps*ny_q+jj)));
        t = toc;
        if display_time
            disp([num2str(((ii*ny_q+jj)/(nx_q*ny_q))*100,4) ... 
                  '% of meas site ' num2str(meas_site) ' of ' ...
                  num2str(num_sites) ', estimated time remaining: ' ...
                  num2str((nx_q*ny_q-ii-ii*ny_q+jj)*t/3600,4) ' hours'])
        end
    end
end
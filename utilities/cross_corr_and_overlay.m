%%%%cross correlation and overlay function expects two input images
%%%%finds maximum cross correlation and overlays query onto template

%%%%for input of query and template image only, returns template image
%%%%with registered query overlaid and query coordinates
%%%%template_overlay, coordinates

%%%%if figure coordinates f1 and f1_pos of query image are provided for 
%%%%user-specified cropping, returns:
%%%%template_overlay, coordinates, template_crop_coords, 
%%%%query_crop_coordinates,query_crop_img

%%%%based on Registering an Image Using Normalized Cross-Correlation
%%%%example MATLAB script

function [template_overlay,coordinates,peak,varargout] = ...
            cross_corr_and_overlay(query,template,enhance,varargin)
template_overlay = template;

%%%%if figure info is provided, ask user to crop images
if length(varargin)==2
    if convertCharsToStrings(class(varargin{1}))=='double' %#ok<*BDSCA>
        f1_pos = varargin{1};
        figure(1)
        imshow(query)
        set(gcf,'Position',f1_pos);
    else
        f1 = varargin{1};
        set(f1,'CData',query)
    end
    figure(1)
    disp(['Select ROI of query image for registration. ' ...
          'Double click inside ROI when finished.'])
    [query_coords,query_crop] = crop_img_user(query);
    if convertCharsToStrings(class(varargin{2}))=='double'
        f2_pos = varargin{2};
        figure(2)
        f2 = imshow(template);
        set(gcf,'Position',f2_pos);
    else
        f2 = varargin{2};
        set(f2,'CData',template)
    end
    figure(2)
    disp(['Select ROI of template image for registration. ' ...
          'Double click inside ROI when finished.'])
    [template_coords,template_crop] = crop_img_user(template);    
%%%%otherwise just use entire images for registration
elseif isempty(varargin) 
    template_coords = [1,1];
    template_crop = template;
    query_crop = query;
else
    error('Incorrect number of additional input arguments.')
end
[query_y,query_x] = size(query_crop);
[temp_y,temp_x] = size(template_crop);
    
%%%%%%%calculate cross correlation and find maxima
try
    %check if query is bigger than template (happens if query has had to
    %be rotated significantly)
    x_diff = temp_x - query_x;
    y_diff = temp_y - query_y;
    if x_diff < 0
        x_diff = abs(x_diff);
    else
        x_diff = 0;
    end
    if y_diff < 0
        y_diff = abs(y_diff);
    else
        y_diff = 0;
    end
    %pad so cross correlation can be calculated
    template_crop = padarray(template_crop,[2*y_diff 2*x_diff],255,'pre');
    
    %optional contrast enhancement can improve registration
    if enhance
        query_crop = adapthisteq(query_crop);
        template_crop = adapthisteq(template_crop);
    end
    cross_corr = normxcorr2e(query_crop,template_crop,'valid');
    [ypeak, xpeak] = find(cross_corr==max(cross_corr(:)));
    peak = max(cross_corr(:));
    
    %%%%%%%find offset of cropped query on cropped template image
    yoffset = ypeak;
    xoffset = xpeak;

    %%%%%%overlay cropped image for user verification
    xbegin = template_coords(1)+xoffset+1;
    xend   = template_coords(1)+xoffset+query_x;
    ybegin = template_coords(2)+yoffset+1;
    yend   = template_coords(2)+yoffset+query_y;
    %coordinates of overlay
    coordinates = [xbegin-2*x_diff,xend-2*x_diff, ...
                   ybegin-2*y_diff,yend-2*y_diff]; 
    template_overlay(ybegin:yend,xbegin:xend) = query_crop;
    %crop out the necessary padding if size(query)>size(template)
    template_overlay = template_overlay(2*y_diff+1:end,2*x_diff+1:end);
catch
    disp('Error calculating cross correlation, try selecting ROIs again')
    coordinates = [1 1 2 2];
    peak = 0;
end

if length(varargin)==2
    try
        set(f2,'CData',template_overlay);
    catch
        disp('Error overlaying images, try selecting ROIs again.')
    end
    varargout{1} = query_coords; %query crop coordinates
    varargout{2} = template_coords;
end
%find rotation of query image relative to template using feature matching
%allows for cropping of query and template images if figure coordinates
%are provided (f1_pos, f2_pos)
%based heavily on visionrecovertform.m example MATLAB script
function [scale,theta,varargout] = ...
          feature_based_rotation(query,template,varargin)
if length(varargin) == 2
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
    disp(['Select ROI of query for feature based image rotation. '...
          'Double click inside ROI when finished.'])
    [~,query_crop] = crop_img_user(query);
    varargout{1} = query_crop;
    if convertCharsToStrings(class(varargin{2}))=='double'
        f2_pos = varargin{2};
        figure(2)
        imshow(template)
        set(gcf,'Position',f2_pos);
    else
        f2 = varargin{2};
        set(f2,'CData',template)
    end
    figure(2)
    disp(['Select ROI of template for feature based image rotation.'...
          'Double click inside ROI when finished.'])
    [~,template_crop] = crop_img_user(template);
    varargout{2} = template_crop;
elseif isempty(varargin)
    query_crop = query;
    template_crop = template;
else
    error('Incorrect number of input arguments.')
end  
ptsTemp  = detectSURFFeatures(template_crop);
ptsQuery = detectSURFFeatures(query_crop);
[featuresTemp, validPtsTempe]  = extractFeatures(template_crop, ptsTemp);
[featuresQuery, validPtsQuery] = extractFeatures(query_crop, ptsQuery);
indexPairs = matchFeatures(featuresTemp, featuresQuery);
matchedTemp  = validPtsTempe(indexPairs(:,1));
matchedQuery = validPtsQuery(indexPairs(:,2));
[tform,~,~] = estimateGeometricTransform(matchedQuery, matchedTemp, ...
                                         'similarity'); 
Tinv  = tform.invert.T;
ss = Tinv(2,1);
sc = Tinv(1,1);
scale = sqrt(ss*ss + sc*sc);
theta = atan2(ss,sc)*180/pi;
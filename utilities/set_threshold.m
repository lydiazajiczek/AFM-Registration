%set_threshold: change and display threshold of image
%inputs: image matrix img, figure f, figure position f_pos
%outputs: user selected threshold value, figure f, boolean test 
function [threshold, test] = set_threshold(img,f)
    %update figure with original image
    set(f,'CData',img);    
    ax = gca;
    ax.set('CLim',[0 255]);
    %user inputs integer threshold value
    prompt = 'Enter threshold value for FOV image (0-255): ';
    threshold = uint8(str2double(input(prompt,'s')));
    img_thresh = double(img<threshold);
    set(f,'CData',img_thresh);
    ax = gca;
    ax.set('CLim',[0 1]);
    %user confirmation, boolean is returned
    prompt = 'Is this threshold level correct? Y/N: ';
    user_input = input(prompt,'s');
    test = all(upper(user_input) == 'Y');
end


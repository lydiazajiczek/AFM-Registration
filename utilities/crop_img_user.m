%crop_img_user: waits for user to draw cropping ROI, 
%returns cropped image and crop coordinates
function [crop_coords,img_crop] = crop_img_user(img)
    crop_rect = imrect;
    crop_rect.wait;
    crop_coords = uint32(crop_rect.getPosition);
    img_crop = imcrop(img,crop_coords);
    crop_rect.delete;
end
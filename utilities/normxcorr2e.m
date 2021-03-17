%%%%%%slightly modified version of normxcorr2, similar to conv2 which
%%%%%%allows for the user to set a parameter called shape: that determines
%%%%%%whether the output image will be the same shape as the original
% C = CONV2(..., SHAPE) returns a subsection of the 2-D
%   convolution with size specified by SHAPE:
%     'full'  - (default) returns the full 2-D convolution,
%     'same'  - returns the central part of the convolution
%               that is the same size as A.
%     'valid' - returns only those parts of the convolution
%               that are computed without the zero-padded edges.
%               size(C) = max([ma-max(0,mb-1),na-max(0,nb-1)],0).

function I = normxcorr2e(template, im, shape)

  if (nargin == 2) || strcmp(shape,'full')
      I = collect(normxcorr2(template, im));
      return
  end

  switch shape
      case 'same'
          pad = floor(size(template)./2);
          center = size(im);
      case 'valid'
          pad = size(template) - 1;
          center = size(im) - pad;
      otherwise
          throw(Mexception('normxcorr2e:BadInput',...
              'SHAPE must be ''full'', ''same'', or ''valid''.'));
  end

  I = normxcorr2(template, im);
  I = I([false(1,pad(1)) true(1,center(1))], ...
        [false(1,pad(2)) true(1,center(2))]);

end
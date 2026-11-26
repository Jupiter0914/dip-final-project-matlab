function ok = supportedShape(shape)
ok = isnumeric(shape) && numel(shape)==2 && all(isfinite(shape)) && ...
    all(shape==fix(shape) & shape>0 & shape<=16382) && prod(double(shape))<=4000000;
end

function s = pixelScores(original,mask)
%空并集对应两份完全相同的空蒙版
assert(isequal(size(original),size(mask)))
fp = nnz(mask & ~original);
fn = nnz(~mask & original);
a = nnz(mask | original);
s = struct('xor',fp+fn,'fp',fp,'fn',fn,'iou',1,'rmse',sqrt((fp+fn)/numel(mask)));
if a > 0
    s.iou = nnz(mask & original)/a;
end
end


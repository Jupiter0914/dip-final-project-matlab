function counts=compareSingleChanges(shape,points,current,ref,changes,expected,flipSets)
%调用生产改边函数取得实际列序像素编号，逐项对照完整画布的翻转集合
[delta,flips,meta]=efSingleChanges(shape,points,current,ref,changes);
assert(isequal(delta(:),expected(:)),'EF:PixelDelta','Single-edit loss differs from full repaint');
assert(isscalar(meta.fallbackCalls) && meta.fallbackCalls>=0 && meta.fallbackCalls<=numel(expected) && meta.fallbackCalls==fix(meta.fallbackCalls),'EF:Fallback','Invalid fallback count');
assert(numel(flips)==numel(flipSets));
count=0;
for j=1:numel(flips)
    actual=double(flips{j}(:)); truth=double(flipSets{j}(:));
    assert(isequal(actual,truth),'EF:PixelSet','Source-pixel IDs differ at edit %d for %s',j,mat2str(changes(j,:)));
    count=count+numel(actual);
end
counts=[numel(flips),count,double(meta.fallbackCalls)];
end

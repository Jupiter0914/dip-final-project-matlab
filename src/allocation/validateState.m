function [state,reason,d]=validateState(prep,rings,mustBeat)
%正式接受的状态总会重新合成全部环，并与原图逐区域对应
state=[]; d=NaN;
counts=cellfun(@(p)size(p,1),rings(:));
if numel(counts)~=numel(prep.parents) || sum(counts)~=prep.target
    reason='wrong_vertex_or_ring_count'; return
end
masks=cell(size(rings)); predicted=false(prep.shape);
for i=1:numel(rings)
    masks{i}=rasterRing(prep.shape,rings{i});
    predicted=xor(predicted,masks{i});
end
d=nnz(prep.raw~=predicted);
if nargin>=3 && d>=mustBeat
    reason='no_strict_xor_improvement'; return
end
reason=vectorCheck(rings,prep.parents);
if ~strcmp(reason,'ok')
    return
end
reason=structureMatch(prep.reference,digitalLayout(predicted));
if strcmp(reason,'ok')
    state=struct('rings',{rings(:)},'d',d,'masks',{masks(:)},'allocation',counts(:)');
end
end

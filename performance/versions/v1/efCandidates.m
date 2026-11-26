function [pairs,eligible,loss,cache,trace]=efCandidates(prep,state,allowCross,cache)
%缓存保存完整有序环的单项代价，组合与排名每轮都重新计算
r=numel(state.rings);
if isempty(cache)
    cache=struct('entry',{cell(r,1)},'version',zeros(r,1));
end
entries=cache.entry; donorParts=cell(r,1); receiverParts=cell(r,1);
loss=zeros(r,1); tracing=nargout>4;
if tracing, rebuilt=false(r,1); end
for t=1:r
    entry=entries{t};
    if isempty(entry) || ~isequal(entry.points,state.rings{t})
        entry=scoreOne(t,state.rings{t},prep.dense{t},prep.refs{t},state.masks{t},prep.shape);
        entries{t}=entry; cache.version(t)=cache.version(t)+1;
        if tracing, rebuilt(t)=true; end
    end
    loss(t)=entry.loss;
    donorParts{t}=entry.donors; receiverParts{t}=entry.receivers;
end
cache.entry=entries;
donors=vertcat(zeros(0,3),donorParts{:});
receivers=vertcat(zeros(0,5),receiverParts{:});
if tracing
    loc=cellfun(@(s)s.location,entries,'UniformOutput',false);
    rx=cellfun(@(s)s.insertIndex,entries,'UniformOutput',false);
    trace=struct('donors',donors,'receivers',receivers,'ringDenseIndices',{loc}, ...
        'donorDenseIndices',vertcat(zeros(0,1),loc{:}),'receiverDenseIndices',vertcat(zeros(0,1),rx{:}), ...
        'rebuiltRings',find(rebuilt),'reusedRings',find(~rebuilt),'ringVersion',cache.version);
end
%保留冻结的平分顺序，三角供点只能服务于同圈非相邻边
receivers=sortrows(receivers); partial=cell(size(donors,1),1); eligible=0;
for d=1:size(donors,1)
    ri=donors(d,2); j=donors(d,3); same=receivers(:,2)==ri;
    allowed=(allowCross && state.allocation(ri)>3) | same;
    allowed=allowed & ~(same & (receivers(:,3)==j | receivers(:,3)==mod(j-2,state.allocation(ri))+1));
    eligible=eligible+nnz(allowed);
    ix=find(allowed,24,'first');
    partial{d}=[donors(d,1)+receivers(ix,1),repmat([ri,j],numel(ix),1),receivers(ix,2:5)];
end
pairs=sortrows(vertcat(zeros(0,7),partial{:})); pairs=pairs(1:min(24,size(pairs,1)),:);
end

function entry=scoreOne(t,p,dense,ref,mask,shape)
%原始弧段、两点线迹和边界回填沿用同一源坐标系
[found,location]=ismember(p,dense,'rows');
assert(all(found),'DIP:NotSourceVertex','Candidate ring is not a subsequence of the original')
n=size(p,1); total=size(dense,1); base=nnz(mask~=ref);
donors=zeros(n,3); receivers=zeros(2*n,5); insertIndex=zeros(2*n,1); nr=0;
for j=1:n
    reduced=p; reduced(j,:)=[];
    donors(j,:)=[nnz(rasterRing(shape,reduced)~=ref)-base,t,j];
    next=mod(j,n)+1;
    count=mod(location(next)-location(j)-1,total);
    if count==0, continue; end
    ids=mod(location(j)+(0:count-1),total)+1;
    arc=dense(ids,:);
    v=p(next,:)-p(j,:); diff=arc-p(j,:);
    frac=max(0,min(1,(diff(:,1)*v(1)+diff(:,2)*v(2))/max(1,sum(v.^2))));
    [~,far]=max(sum((diff-frac.*v).^2,2));
    for a=unique([far,floor(count/2)+1])
        q=arc(a,:); inserted=[p(1:j,:);q;p(j+1:end,:)];
        nr=nr+1;
        receivers(nr,:)=[nnz(rasterRing(shape,inserted)~=ref)-base,t,j,q];
        insertIndex(nr)=ids(a);
    end
end
entry=struct('points',p,'location',location,'loss',base,'donors',donors, ...
    'receivers',receivers(1:nr,:),'insertIndex',insertIndex(1:nr));
end

function [pairs,eligible]=moveCandidates(prep,state,allowCross,method)
%候选使用变动前的环编号和顶点下标，两种方法共享同一组单独删插评分
if nargin<4, method='within_full'; end
oldShort=any(strcmp(method,{'within_old','cross_oldtri'}));
triangles=~oldShort && ~endsWith(method,'_oldtri');
r=numel(state.rings); maxN=sum(state.allocation);
donors=zeros(maxN,3); receivers=zeros(2*maxN,5); nd=0; nr=0;
for t=1:r
    p=state.rings{t}; dense=prep.dense{t}; ref=prep.refs{t};
    [found,location]=ismember(p,dense,'rows');
    assert(all(found),'DIP:NotSourceVertex','Candidate ring is not a subsequence of the original')
    n=size(p,1); total=size(dense,1); base=nnz(state.masks{t}~=ref);
    for j=1:n
        if triangles || n>3
            reduced=p; reduced(j,:)=[];
            nd=nd+1;
            donors(nd,:)=[nnz(rasterRing(prep.shape,reduced)~=ref)-base,t,j];
        end
        next=mod(j,n)+1;
        count=mod(location(next)-location(j)-1,total);
        if count==0, continue; end
        arc=dense(mod(location(j)+(0:count-1),total)+1,:);
        v=p(next,:)-p(j,:); diff=arc-p(j,:);
        frac=max(0,min(1,(diff(:,1)*v(1)+diff(:,2)*v(2))/max(1,sum(v.^2))));
        [~,far]=max(sum((diff-frac.*v).^2,2));
        for a=unique([far,floor(count/2)+1])
            q=arc(a,:); inserted=[p(1:j,:);q;p(j+1:end,:)];
            nr=nr+1;
            receivers(nr,:)=[nnz(rasterRing(prep.shape,inserted)~=ref)-base,t,j,q];
        end
    end
end
receivers=receivers(1:nr,:); donors=donors(1:nd,:);
if oldShort
    donors=historicalShortlist(donors,5);
    receivers=historicalShortlist(receivers,10);
    nd=size(donors,1);
end
%每个供点最多保留自身排在前二十四的组合，全局前二十四一定在其并集中
receivers=sortrows(receivers); partial=cell(nd,1); eligible=0;
for d=1:nd
    ri=donors(d,2); j=donors(d,3); same=receivers(:,2)==ri;
    allowed=(allowCross && state.allocation(ri)>3) | same;
    allowed=allowed & ~(same & (receivers(:,3)==j | receivers(:,3)==mod(j-2,state.allocation(ri))+1));
    eligible=eligible+nnz(allowed);
    ix=find(allowed,24,'first');
    partial{d}=[donors(d,1)+receivers(ix,1),repmat([ri,j],numel(ix),1),receivers(ix,2:5)];
end
pairs=sortrows(vertcat(zeros(0,7),partial{:})); pairs=pairs(1:min(24,size(pairs,1)),:);
end

function out=historicalShortlist(items,n)
items=sortrows(items);
[~,first]=unique(items(:,2),'first');
out=items(unique([reshape(1:min(n,size(items,1)),[],1);first]),:);
end

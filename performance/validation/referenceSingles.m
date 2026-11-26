function [donors,receivers]=referenceSingles(prep,state)
%独立列出每条合法供点和接收边，费用均由整圈回填实测
donors=zeros(0,3); receivers=zeros(0,5);
for ri=1:numel(state.rings)
    p=state.rings{ri}; dense=prep.dense{ri}; ref=prep.refs{ri};
    n=size(p,1); nDense=size(dense,1);
    [ok,sourceIndex]=ismember(p,dense,'rows'); assert(all(ok));
    old=nnz(rasterRing(prep.shape,p)~=ref);
    for j=1:n
        q=p; q(j,:)=[];
        donors(end+1,:)=[nnz(rasterRing(prep.shape,q)~=ref)-old,ri,j];
        k=mod(j,n)+1;
        run=sourceIndex(j)+1:sourceIndex(k)+(sourceIndex(k)<=sourceIndex(j))*nDense-1;
        if isempty(run), continue; end
        arc=dense(mod(run-1,nDense)+1,:);
        chord=p(k,:)-p(j,:); u=arc-p(j,:);
        fraction=max(0,min(1,sum(u.*chord,2)/max(1,sum(chord.^2))));
        [~,far]=max(sum((u-fraction.*chord).^2,2));
        for candidate=unique([far,floor(size(arc,1)/2)+1])
            point=arc(candidate,:); q=[p(1:j,:);point;p(j+1:end,:)];
            receivers(end+1,:)=[nnz(rasterRing(prep.shape,q)~=ref)-old,ri,j,point];
        end
    end
end
donors=sortrows(donors); receivers=sortrows(receivers);
end

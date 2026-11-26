function [dp,per,pool,cost]=allocateCounts(errors,dense,target)
%从最后一圈向前做动态规划，等价最优时选择当前圈更小的点数
r=numel(dense);
if r==0
    dp=zeros(1,0); per=dp; pool=dp; cost=0; return
end
dp=[]; suffix=inf(r+1,target+1); suffix(end,1)=0; choice=zeros(r,target+1);
for i=r:-1:1
    available=find(isfinite(errors{i}));
    for k=available(:)'
        rest=0:target-k;
        trial=errors{i}(k)+suffix(i+1,rest+1);
        spent=rest+k+1;
        update=trial<suffix(i,spent);
        suffix(i,spent(update))=trial(update);
        choice(i,spent(update))=k;
    end
end
if isfinite(suffix(1,target+1))
    left=target; dp=zeros(1,r);
    for i=1:r
        dp(i)=choice(i,left+1); left=left-dp(i);
    end
end
cap=cellfun(@(p)size(p,1),dense(:))';
perim=cellfun(@(p)sum(hypot(p(:,1)-p([end 1:end-1],1),p(:,2)-p([end 1:end-1],2))),dense(:))';
lo=0; hi=max(cap./perim)+1;
for t=1:50
    mid=(lo+hi)/2;
    if sum(min(cap,max(3,mid*perim)))<target
        lo=mid;
    else
        hi=mid;
    end
end
ideal=min(cap,max(3,(lo+hi)*.5*perim)); per=min(cap,max(3,floor(ideal+1e-10)));
[~,rank]=sort(ideal-per,'descend');
for j=rank
    if sum(per)>=target, break; end
    if per(j)<cap(j), per(j)=per(j)+1; end
end
bases=zeros(0,r);
if ~isempty(dp), bases=dp; end
if admissible(per,errors), bases=[bases;per]; end
pool=bases;
if r==2
    for q=find(isfinite(errors{1}))
        counts=[q,target-q];
        if admissible(counts,errors), pool(end+1,:)=counts; end
    end
else
    for b=1:size(bases,1)
        for donor=1:r
            for recipient=1:r
                if donor==recipient, continue; end
                for step=[1 2 4]
                    c=bases(b,:); c(donor)=c(donor)-step; c(recipient)=c(recipient)+step;
                    if admissible(c,errors), pool(end+1,:)=c; end
                end
            end
        end
    end
end
pool=unique(pool,'rows');
cost=zeros(size(pool,1),1);
for i=1:r
    cost=cost+reshape(errors{i}(pool(:,i)),[],1);
end
[~,order]=sortrows([cost,pool]);
pool=pool(order,:); cost=cost(order);
if size(pool,1)>40
    keep=ismember(pool,bases,'rows'); keep(1:20)=true;
    slots=40-nnz(keep);
    if slots==1
        selected=1;
    else
        selected=1+floor(linspace(0,size(pool,1)-1,slots));
    end
    keep(selected)=true;
    missing=find(~keep,40-nnz(keep),'first'); keep(missing)=true;
    pool=pool(keep,:); cost=cost(keep);
end
end

function ok=admissible(c,errors)
ok=true;
for i=1:numel(c)
    if c(i)<3 || c(i)>numel(errors{i}) || ~isfinite(errors{i}(c(i)))
        ok=false; return
    end
end
end

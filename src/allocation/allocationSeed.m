function [state,info]=allocationSeed(prep)
%首个通过几何和数字结构的分配立即成为种子，保留此前每次拒绝的原因
state=[]; attempt=struct('counts',{},'additive',{},'xor',{},'reason',{});
info=struct('status',prep.status,'reason',prep.reason,'dpCounts',[],'perimeterCounts',[], ...
    'initialXor',NaN,'initialReason','unavailable','legalXor',NaN,'dpRings',{{}}, ...
    'poolSize',0,'attempts',{attempt});
if ~strcmp(prep.status,'success'), return; end
r=numel(prep.dense);
if r==0
    [state,~,d]=validateState(prep,cell(0,1));
    info.initialXor=d; info.legalXor=d; info.initialReason='ok'; info.poolSize=1;
    info.attempts=struct('counts',[],'additive',0,'xor',0,'reason','ok');
    return
end
levels=cell(r,1); errors=cell(r,1);
cap=prep.target-3*(r-1);
for i=1:r
    bank=ringHierarchy(prep.dense{i},cap);
    e=inf(1,numel(bank));
    for q=3:numel(bank)
        if ~strcmp(vectorCheck(bank(q),-1),'ok'), continue; end
        e(q)=nnz(rasterRing(prep.shape,bank{q})~=prep.refs{i});
    end
    levels{i}=bank; errors{i}=e;
end
[dp,per,pool,cost]=allocateCounts(errors,prep.dense,prep.target);
info.dpCounts=dp; info.perimeterCounts=per; info.poolSize=size(pool,1);
info.status='search_no_valid_output'; info.reason='no_valid_allocation_in_pool';
for n=1:size(pool,1)
    c=pool(n,:); rings=cell(r,1);
    for i=1:r
        rings{i}=levels{i}{c(i)};
    end
    [candidate,reason,d]=validateState(prep,rings);
    info.attempts(end+1)=struct('counts',c,'additive',cost(n),'xor',d,'reason',reason);
    if isequal(c,dp)
        info.dpRings=rings; info.initialReason=reason; info.initialXor=d;
    end
    if strcmp(reason,'ok')
        state=candidate; info.status='success'; info.reason='ok'; info.legalXor=d;
        break
    end
end
end

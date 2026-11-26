function exploreAllocation(root,manifest,out)
%在开发源上比较分配池的可加排序、整图排序和限次结构修复
rows=struct([]);
poolRows=struct('id',{},'budget',{},'rank',{},'counts',{},'additive',{},'xor',{},'reason',{});
checks=struct('id',{},'budget',{},'policy',{},'check',{},'kind',{},'counts',{},'reason',{},'xor',{});
for s=1:height(manifest)
    raw=readFrozenMask(root,manifest(s,:)); id=manifest.id(s);
    [rings,~]=extractRings(raw); budgets=[128 256 512];
    if numel(rings)>=8, budgets=[budgets 1024]; end
    for budget=budgets
        prep=prepareMask(raw,budget); n=numel(prep.dense);
        rec=struct('id',id,'budget',budget,'rings',n,'status',string(prep.status), ...
            'reason',string(prep.reason),'dp_reason',"unavailable",'dp_xor',NaN,'per_reason',"unavailable", ...
            'per_xor',NaN,'pool_size',0,'legal_pool',0,'first_legal_xor',NaN,'best_legal_xor',NaN, ...
            'legal_pairs',0,'ranking_disagreements',0,'ordered_oracles',0,'ordered_xor',NaN, ...
            'context_oracles',0,'context_xor',NaN,'blocked',0);
        if prep.status=="success" && n>0
            banks=cell(n,1); errors=cell(n,1);
            for i=1:n
                banks{i}=ringHierarchy(prep.dense{i},prep.target-3*(n-1));
                errors{i}=inf(1,numel(banks{i}));
                for k=3:numel(banks{i})
                    ring=banks{i}{k};
                    if strcmp(vectorCheck({ring},-1),'ok')
                        errors{i}(k)=nnz(rasterRing(prep.shape,ring)~=prep.refs{i});
                    end
                end
            end
            [dp,per,pool,cost]=allocateCounts(errors,prep.dense,prep.target);
            rec.pool_size=size(pool,1);
            [rec.dp_reason,rec.dp_xor]=inspectCounts(dp,prep,banks,errors);
            [rec.per_reason,rec.per_xor]=inspectCounts(per,prep,banks,errors);
            measures=zeros(0,2);
            for j=1:size(pool,1)
                [reason,d]=inspectCounts(pool(j,:),prep,banks,errors);
                if reason=="ok", measures(end+1,:)=[cost(j),d]; end
                poolRows(end+1)=struct('id',id,'budget',budget,'rank',j,'counts',string(mat2str(pool(j,:))), ...
                    'additive',cost(j),'xor',d,'reason',reason);
            end
            rec.legal_pool=size(measures,1);
            if isempty(measures)
                rec.status="search_no_valid_output"; rec.reason="no_legal_allocation";
            else
                rec.first_legal_xor=measures(1,2); rec.best_legal_xor=min(measures(:,2));
                for a=1:size(measures,1)
                    differences=sign(measures(a+1:end,:)-measures(a,:));
                    rec.legal_pairs=rec.legal_pairs+size(differences,1);
                    rec.ranking_disagreements=rec.ranking_disagreements+nnz(differences(:,1)~=differences(:,2));
                end
            end
            for policy=["ordered","context"]
                [trace,recovered,blocked]=repairAllocation(prep,banks,errors,dp,policy);
                rec.(char(policy+"_oracles"))=numel(trace);
                rec.(char(policy+"_xor"))=recovered;
                rec.blocked=max(rec.blocked,blocked);
                for j=1:numel(trace)
                    checks(end+1)=struct('id',id,'budget',budget,'policy',policy,'check',j, ...
                        'kind',trace(j).kind,'counts',trace(j).counts,'reason',trace(j).reason,'xor',trace(j).xor);
                end
            end
        end
        rows=[rows;rec];
    end
    writetable(struct2table(rows),fullfile(out,'allocation.csv'));
    if ~isempty(poolRows), writetable(struct2table(poolRows),fullfile(out,'allocation_pool.csv')); end
    if ~isempty(checks), writetable(struct2table(checks),fullfile(out,'repair_checks.csv')); end
end
end

function [reason,d]=inspectCounts(c,prep,banks,errors)
d=NaN; reason="unavailable";
if isempty(c), return; end
rings=cell(numel(c),1);
for i=1:numel(c)
    if c(i)>numel(errors{i}) || ~isfinite(errors{i}(c(i))), return; end
    rings{i}=banks{i}{c(i)};
end
[~,r,d]=validateState(prep,rings); reason=string(r);
end

function [trace,d,blocked]=repairAllocation(prep,banks,errors,dp,policy)
trace=struct('kind',{},'counts',{},'reason',{},'xor',{}); d=NaN; blocked=0;
if isempty(dp), return; end
tried=zeros(0,numel(dp));
[reason,score]=check(dp);
if reason=="ok", d=score; return; end
if policy=="context"
    filtered=errors; c=dp;
    for sweep=1:4
        previous=blocked; priority=zeros(numel(c),1);
        for i=1:numel(c), priority(i)=-errors{i}(c(i))/max(1,nnz(prep.refs{i})); end
        [~,order]=sort(priority);
        for i=order'
            if numel(trace)>=63, break; end
            if c(i)==size(prep.dense{i},1), continue; end
            rings=prep.dense; rings{i}=banks{i}{c(i)};
            counts=cellfun(@(p) size(p,1),rings)';
            probe=prep; probe.target=sum(counts);
            [~,r,v]=validateState(probe,rings);
            trace(end+1)=struct('kind',"one_ring_in_exact_context",'counts',string(mat2str(counts)),'reason',string(r),'xor',v);
            if ~strcmp(r,'ok') && isfinite(filtered{i}(c(i)))
                filtered{i}(c(i))=inf; blocked=blocked+1;
            end
        end
        if previous==blocked || numel(trace)>=64, break; end
        best=bestAllocations(filtered,prep.target,1);
        if isempty(best), break; end
        c=best(1,2:end);
        if ismember(c,tried,'rows'), break; end
        [reason,score]=check(c); if reason=="ok", d=score; return; end
    end
end
%每个后缀和只需保留前六十四项，足以回答预算内的有序询问
ranked=bestAllocations(errors,prep.target,64);
for j=1:size(ranked,1)
    if numel(trace)>=64, break; end
    c=ranked(j,2:end); if ismember(c,tried,'rows'), continue; end
    [reason,score]=check(c);
    if reason=="ok", d=score; return; end
end

    function [r,v]=check(c)
        [r,v]=inspectCounts(c,prep,banks,errors); tried(end+1,:)=c;
        trace(end+1)=struct('kind',"output",'counts',string(mat2str(c)),'reason',r,'xor',v);
    end
end

function out=bestAllocations(errors,total,limit)
suffix=cell(1,total+1); suffix{1}=0;
for i=numel(errors):-1:1
    next=cell(size(suffix)); available=find(~cellfun(@isempty,suffix))-1;
    for k=find(isfinite(errors{i}))
        for used=available(available+k<=total)
            old=suffix{used+1};
            vals=[errors{i}(k)+old(:,1),repmat(k,size(old,1),1),old(:,2:end)];
            slot=used+k+1; ranked=sortrows([next{slot};vals]);
            next{slot}=ranked(1:min(limit,size(ranked,1)),:);
        end
    end
    suffix=next;
end
out=suffix{end};
end

function run_supplements(root)
%在计时结束后用相同 DP 银行重建未经筛查的分配和合法起点
cfg=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');
events=readtable(fullfile(root,'results','events.csv'),'TextType','string');
cost=cell(396,17); audits=cell(0,10); allocations=cell(0,9); n=0; details={};
out=fullfile(root,'local','structure');
if ~isfolder(out),mkdir(out);end
for i=1:height(cfg)
    row=cfg(i,:);raw=readFrozenMask(root,row); budgets=256;
    if row.supplement,budgets=[128 256 512];end
    se=events(events.dataset==row.dataset & events.id==row.id,:);
    for b=budgets
        prep=prepareMask(raw,b);
        [state,info]=allocationSeed(prep);
        na="";legal="";rejected=0;
        if ~isempty(info.dpRings) || (prep.highVertices==0 && strcmp(prep.status,'success'))
            na=saveBlob(out,packPM31(prep.shape,info.dpRings,prep.parents));
        end
        if ~isempty(state)
            legal=saveBlob(out,packPM31(prep.shape,state.rings,prep.parents));
            observed=unique(se.sha256(se.method=="seed" & se.budget==b & se.round==0));
            assert(isscalar(observed) && observed==legal)
        else
            assert(~any(se.method=="seed" & se.budget==b))
        end
        if ~isempty(info.attempts),rejected=nnz(string({info.attempts.reason})~="ok");end
        for k=1:numel(info.attempts)
            step=info.attempts(k);
            allocations(end+1,:)={row.dataset,row.id,b,k,join(string(step.counts),','),step.additive, ...
                step.xor,string(step.reason),isequal(step.counts,info.dpCounts)};
            if isempty(step.counts), allocations{end,5}=""; end
        end
        naiveCounts=join(string(info.dpCounts),',');if isempty(info.dpCounts),naiveCounts="";end
        legalCounts="";
        if ~isempty(state) && ~isempty(state.allocation),legalCounts=join(string(state.allocation),',');end
        n=n+1;cost(n,:)={row.dataset,row.id,b,string(info.status),string(info.reason), ...
            info.initialXor,info.legalXor,rejected,string(info.initialReason),na,legal,info.poolSize, ...
            info.legalXor-info.initialXor,numel(info.attempts),naiveCounts,legalCounts,prep.lowerBound};
        if b==256 && row.supplement
            subset=se(se.budget==256 & se.session==1 & se.rep==1 & ismember(se.method,["seed","cross","exact"]),:);
            for digest=unique(subset.sha256).'
                bytes=readBytes(fullfile(root,'local','blobs',digest+".pm3"));
                assert(strcmp(sha256Bytes(bytes),digest),'DIP:Digest','Checkpoint SHA mismatch')
                [~,rings,par]=decodePM31(bytes); assert(isequal(par,prep.parents))
                [st,reason]=validateState(prep,rings);assert(strcmp(reason,'ok'))
                [~,~,a]=exchangeStep(prep,st,'exact',true);
                audits(end+1,:)={row.dataset,row.id,digest,a.proposedPairs,a.xorImproving, ...
                    a.skippedByAdd,a.validSkippedByAdd,a.choicesDiffer,a.exactChoice,a.additiveChoice};
                details{end+1}=struct('dataset',row.dataset,'id',row.id,'sha256',digest,'audit',a);
            end
        end
    end
end
assert(n==396)
writetable(cell2table(cost,'VariableNames',{'dataset','id','budget','status','reason','initial_xor', ...
    'legal_xor','rejected','initial_reason','initial_sha','legal_sha','pool_size', ...
    'validity_cost_xor','tested_allocations','initial_counts','legal_counts','lower_bound'}),fullfile(root,'results','structural_cost.csv'))
writetable(cell2table(audits,'VariableNames',{'dataset','id','sha256','proposed','improving','skipped', ...
    'valid_skipped','choices_differ','exact_choice','additive_choice'}),fullfile(root,'results','exact_screen.csv'))
writetable(cell2table(allocations,'VariableNames',{'dataset','id','budget','rank','counts','additive', ...
    'xor','reason','is_independent_dp'}),fullfile(root,'results','allocation_attempts.csv'))
writeJson(fullfile(root,'results','exact_candidates.json'),details)
end

function digest=saveBlob(folder,bytes)
digest=string(sha256Bytes(bytes)); dest=fullfile(folder,digest+".pm3");
if ~isfile(dest)
    f=fopen(dest,'wb');assert(f>=0);n=fwrite(f,bytes,'uint8');s=fclose(f);assert(n==numel(bytes)&&s==0)
end
assert(strcmp(sha256Bytes(readBytes(dest)),digest),'DIP:Digest','Structure archive SHA mismatch')
end

function efCollect(root,stage)
%从接收日志和独立二进制重建观察，同时逐个文件复算像素及全图拓扑
stage=string(stage); efSetup(root,stage);
R=fullfile(root,'perf_results',stage);
[names,~]=efMethods(stage);
if startsWith(stage,"dev")
    rows=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
else
    rows=readtable(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv'),'TextType','string');
    if stage=="fixed",rows=rows(logical(rows.fixed48),:);end
end
n=height(rows)*numel(names)*6; calls=cell(n,22); events=cell(9*n,19);
seen=containers.Map('KeyType','char','ValueType','any');
sources=containers.Map('KeyType','char','ValueType','any');
nCalls=0;nEvents=0;pids=zeros(3,1);fallbackCounts=nan(n,3);
for sid=1:3
    folder=fullfile(R,"S"+sid);meta=jsondecode(fileread(fullfile(folder,'start.json')));
    finish=jsondecode(fileread(fullfile(folder,'complete.json')));pids(sid)=meta.pid;
    assert(finish.calls==n/3 && finish.pid==meta.pid && meta.threads==1)
    for rep=1:2
        jobs=efSchedule(rows,names,stage,sid,rep);
        fid=fopen(fullfile(folder,"rep"+rep+".jsonl"),'rt','n','UTF-8');assert(fid>=0)
        guard=onCleanup(@()fclose(fid));
        for j=1:height(jobs)
            row=rows(jobs.row(j),:);id=char(row.id);
            if ~isKey(sources,id)
                raw=readFrozenMask(root,row);valid=true;parents=[];ref=[];
                try
                    [dense,parents]=extractRings(raw);
                    valid=isequal(raw,renderRings(size(raw),dense));
                    if valid,ref=digitalLayout(raw);end
                catch err
                    if ~ismember(string(err.identifier),["DIP:Unsupported","DIP:InvalidGeometry"]),rethrow(err);end
                    valid=false;
                end
                sources(id)=struct('raw',raw,'parents',parents,'ref',ref,'valid',valid);
            end
            src=sources(id);
            for pos=1:numel(names)
                line=fgetl(fid);assert(ischar(line),'DIP:MissingCall','Truncated measured block')
                t=jsondecode(line);z=t.result;
                assert(string(t.id)==row.id && string(t.dataset)==row.dataset && t.session==sid && ...
                    t.rep==rep && t.budget==256 && t.position==pos && string(t.method)==jobs.methods{j}(pos))
                identity={string(t.dataset),string(t.id),sid,rep,t.budget,string(t.method)};
                first=NaN; last=""; allSha=strings(1,numel(t.events)); beforeX=Inf; previous=0;
                if ~src.valid,assert(strcmp(z.status,'unsupported_representation'));end
                if strcmp(z.status,'success')
                    assert(~isempty(t.events) && z.rings==numel(src.parents))
                else
                    assert(isempty(t.events) && ~strcmp(z.status,'program_error'))
                end
                for k=1:numel(t.events)
                    e=t.events(k);h=string(e.sha256);
                    assert(e.round==k-1 && e.received_ms>=previous && e.serialized_ms<=e.received_ms && ...
                        e.received_ms<=z.return_ms && e.nbytes<=t.budget && e.xor<beforeX)
                    key=[id '/' char(h)];
                    if ~isKey(seen,key)
                        bytes=readBytes(fullfile(root,'local','perf','blobs',h+".pm3"));
                        assert(strcmp(sha256Bytes(bytes),h))
                        [mask,rings,parents]=decodePM31(bytes);
                        assert(isequal(parents,src.parents) && isequal(size(mask),size(src.raw)))
                        assert(strcmp(structureMatch(src.ref,digitalLayout(mask)),'ok'))
                        assert(isequal(packPM31(size(mask),rings,parents),bytes))
                        seen(key)=[numel(bytes),nnz(mask~=src.raw)];
                    end
                    assert(isequal(seen(key),[e.nbytes,e.xor]))
                    if k==1,first=e.received_ms;nbytes=e.nbytes;else,assert(e.nbytes==nbytes);end
                    nEvents=nEvents+1;
                    events(nEvents,:)=[identity,{e.round,e.xor,e.nbytes,h,e.received_ms,e.serialized_ms, ...
                        optional(e.donor),optional(e.receiver),optional(e.deleted_x),optional(e.deleted_y), ...
                        optional(e.inserted_x),optional(e.inserted_y),e.received_ms-previous}];
                    previous=e.received_ms; beforeX=e.xor;allSha(k)=h;last=h;
                end
                %工作量指纹含每次尝试及是否获准，也含全部实际交付字节摘要
                trace=strings(numel(z.rounds),1);accepted=0;
                for k=1:numel(z.rounds)
                    if iscell(z.rounds),a=z.rounds{k};else,a=z.rounds(k);end
                    if a.accepted
                        accepted=accepted+1;
                        assert(accepted+1<=numel(t.events))
                        event=t.events(accepted+1);prev=t.events(accepted);
                        assert(event.round==k && a.xorBefore==prev.xor && a.xorAfter==event.xor && ...
                            a.donor==event.donor && a.receiver==event.receiver)
                    else
                        assert(k==numel(z.rounds))
                    end
                    trace(k)=join(string([a.eligiblePairs a.proposedPairs a.fullChecks a.structuralRejects ...
                        a.accepted a.xorBefore a.xorAfter]),",");
                end
                assert(numel(t.events)==accepted+double(strcmp(z.status,'success')))
                sig=sha256Bytes(unicode2native(char(join([string(z.status);allSha(:);trace],"|")),'UTF-8'));
                nCalls=nCalls+1;
                if isfield(z,'fastCounters')
                    u=z.fastCounters;assert(u.fallbackCalls==u.baseLimitFallbacks+u.editLimitFallbacks)
                    fallbackCounts(nCalls,:)=[u.fallbackCalls u.baseLimitFallbacks u.editLimitFallbacks];
                end
                calls(nCalls,:)=[identity,{string(z.status),string(z.reason),z.rings,logical(t.nonempty), ...
                    z.return_ms,z.end_ms,first,numel(t.events),last,string(sig),t.input_ms,t.write_ms,pos, ...
                    t.memory_before,t.memory_after,numel(z.rounds)}];
            end
        end
        assert(~ischar(fgetl(fid)),'DIP:ExtraRows','Unexpected trailing trials')
        clear guard
    end
end
assert(numel(unique(pids))==3 && nCalls==n)
key={'dataset','id','session','rep','budget','method'};
c=cell2table(calls,'VariableNames',[key,{'status','reason','rings','nonempty','return_ms','search_end_ms', ...
    'first_ms','n_events','final_sha','trace_sha','input_ms','write_ms','position','memory_before','memory_after','attempts'}]);
c.fallback_calls=fallbackCounts(:,1);c.base_limit_fallbacks=fallbackCounts(:,2);c.edit_limit_fallbacks=fallbackCounts(:,3);
e=cell2table(events(1:nEvents,:),'VariableNames',[key,{'round','xor','nbytes','sha256','received_ms','serialized_ms', ...
    'donor','receiver','deleted_x','deleted_y','inserted_x','inserted_y','interval_ms'}]);
assert(height(unique(c(:,key)))==n)
initial=e(e.round==0,:);initial.start_type=repmat("dp",height(initial),1);
initial.start_type(contains(initial.method,"geom"))="geometry";
[g,starts]=findgroups(initial(:,{'dataset','id','budget','start_type'}));
starts.distinct_files=splitapply(@(v)numel(unique(v)),initial.sha256,g);
starts.delivered=splitapply(@numel,initial.round,g);
assert(all(starts.distinct_files==1),'DIP:SeedMismatch','Independent deterministic starts differ')
writetable(starts,fullfile(R,'initial_states.csv'))
if stage=="fixed" || stage=="timed"
    pairKey={'dataset','id','session','rep','budget'};
    for mechanism=["within","cross"]
        a=sortrows(c(c.method=="old_"+mechanism,:),pairKey);
        b=sortrows(c(c.method=="fast_"+mechanism,:),pairKey);
        assert(isequal(a(:,pairKey),b(:,pairKey)))
        mismatch=a.status~=b.status | a.reason~=b.reason | ~(a.rings==b.rings | (isnan(a.rings) & isnan(b.rings)));
        if stage=="fixed",mismatch=mismatch | a.trace_sha~=b.trace_sha | a.n_events~=b.n_events;end
        if any(mismatch)
            writetable(a(mismatch,:),fullfile(R,"mismatch_reference_"+mechanism+".csv"));
            writetable(b(mismatch,:),fullfile(R,"mismatch_fast_"+mechanism+".csv"));
            error('DIP:FormalDivergence','Terminal or fixed-work state mismatch; inspect the preserved measured journals')
        end
    end
end
writetable(c,fullfile(R,'calls.csv'));writetable(e,fullfile(R,'events.csv'))
writeJson(fullfile(R,'journal_audit.json'),struct('calls',height(c),'events',height(e),'source_files',seen.Count, ...
    'sources',sources.Count,'process_ids',pids,'program_exceptions',nnz(c.status=="program_error")));
end

function v=optional(x)
v=x;if isempty(v),v=NaN;end
end

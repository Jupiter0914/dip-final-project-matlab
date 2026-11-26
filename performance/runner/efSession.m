function efSession(root,stage,sid)
%启动后从内存原图分别调用各编码器，三个独立单线程进程串行测量
stage=string(stage); sid=double(sid); efSetup(root,stage);
assert(maxNumCompThreads==1 && ismember(sid,1:3))
disabled=profile('status');assert(strcmpi(disabled.ProfilerStatus,'off'))
dev=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
assert(height(dev)==36 && all(dev.official=="trainval"))
if startsWith(stage,"dev")
    assert(isfile(fullfile(root,'perf_results',stage,'equivalence.ok')),'DIP:Gate','Complete current candidate equivalence first')
    efDevGuard(root,stage,'verify');
    stages=stage;
else
    assert(stage=="confirm")
    efLock(root,'verify');
    stages=["timed","fixed"];
end
identity=getenv('DIP_PERF_LAUNCH_MS');
pid=feature('getpid');startup=posixtime(datetime('now','TimeZone','UTC'))*1000-str2double(identity);
warm=readFrozenMask(root,dev(dev.id=="Bengal_187",:));
[allNames,allBase]=efMethods(stages(1));
warmLog=cell(numel(allNames),1);
for k=1:numel(allNames)
    [t,e]=invoke(warm,allNames(k),allBase(k),Inf,1);
    assert(strcmp(t.status,'success') && ~isempty(e))
    if ~strcmp(allBase(k),"matlab_geom"),assert(numel(t.rounds)==1);end
    warmLog{k}=struct('method',allNames(k),'ms',t.return_ms,'events',numel(e),'rounds',numel(t.rounds));
end
for grid=stages
    [names,base]=efMethods(grid);
    if startsWith(grid,"dev")
        rows=dev; maxMs=Inf;
    else
        rows=readtable(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv'),'TextType','string');
        assert(height(rows)==200 && nnz(rows.fixed48)==48)
        if grid=="fixed",rows=rows(logical(rows.fixed48),:);maxMs=Inf;else,maxMs=200;end
    end
    out=fullfile(root,'perf_results',grid,sprintf('S%d',sid));
    assert(~isfolder(out),'DIP:ExistingSession','Refuse to overwrite %s',out)
    mkdir(out);
    mem=memory;
    writeJson(fullfile(out,'start.json'),struct('session',sid,'pid',pid,'stage',grid, ...
        'source_count',height(rows),'engine',version,'threads',maxNumCompThreads,'startup_ms',startup, ...
        'matlab_bytes_after_warmup',mem.MemUsedMATLAB,'warmup',{warmLog}));
    folder=fullfile(root,'local','perf','blobs'); if ~isfolder(folder),mkdir(folder);end
    count=0;
    for rep=1:2
        jobs=efSchedule(rows,names,grid,sid,rep);
        path=fullfile(out,sprintf('rep%d.jsonl',rep));
        for j=1:height(jobs)
            row=rows(jobs.row(j),:);
            timer=tic; raw=readFrozenMask(root,row); inputMs=1000*toc(timer); nonempty=any(raw,'all');
            methodOrder=jobs.methods{j};
            for m=1:numel(methodOrder)
                name=methodOrder(m);
                before=memory;
                [t,e]=invoke(raw,name,base(names==name),maxMs,8);
                after=memory;
                disk=tic;
                for k=1:numel(e)
                    bytes=e(k).bytes; sha=sha256Bytes(bytes);e(k).sha256=sha;
                    dest=fullfile(folder,[sha '.pm3']);
                    if ~isfile(dest)
                        fid=fopen([dest '.part'],'wb');assert(fid>=0)
                        written=fwrite(fid,bytes,'uint8');closed=fclose(fid);
                        assert(written==numel(bytes) && closed==0)
                        [ok,msg]=movefile([dest '.part'],dest);assert(ok,'%s',msg)
                    end
                end
                writeMs=1000*toc(disk);
                record=struct('dataset',row.dataset,'id',row.id,'session',sid,'rep',rep,'budget',256,'method',name, ...
                    'stage',grid,'position',m,'nonempty',nonempty,'input_ms',inputMs,'write_ms',writeMs, ...
                    'memory_before',before.MemUsedMATLAB,'memory_after',after.MemUsedMATLAB, ...
                    'result',t,'events',rmfield(e,'bytes'));
                fid=fopen(path,'a','n','UTF-8');assert(fid>=0)
                fprintf(fid,'%s\n',jsonencode(record));assert(fclose(fid)==0)
                count=count+1;
                if strcmp(t.status,'program_error'),error('DIP:TrialException','%s/%s %s: %s',row.id,name,grid,t.reason);end
            end
            if mod(j,24)==0,fprintf('%s S%d repeat %d: %d/%d sources\n',grid,sid,rep,j,height(jobs));end
        end
    end
    writeJson(fullfile(out,'complete.json'),struct('pid',pid,'calls',count));
end
end

function [t,e]=invoke(raw,name,base,maxMs,rounds)
if startsWith(name,"old_")
    [t,e]=measureEncoding(raw,256,char(base),maxMs,rounds);
else
    [t,e]=efMeasure(raw,256,char(base),maxMs,rounds);
end
end

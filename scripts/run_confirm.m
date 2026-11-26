function run_confirm(root,session)
%一个进程只执行一个已冻结会话，独立运行中的每个方法
session = double(session);
assert(isscalar(session) && ismember(session,1:3) && maxNumCompThreads==1)
lock = freezeExperiment(root,'verify');
cfg = jsondecode(fileread(fullfile(root,'configs','confirm.json')));
sources = readtable(fullfile(root,cfg.manifest),'TextType','string');
assert(height(sources)==300 && numel(unique(sources.dataset+"/"+sources.id))==300)
sel = sort(sources.dataset(logical(sources.supplement))+"/"+sources.id(logical(sources.supplement)));
assert(isstruct(cfg.conditions) || iscell(cfg.conditions))
for n=2:4
    if iscell(cfg.conditions), condition=cfg.conditions{n}; else, condition=cfg.conditions(n); end
    assert(isequal(sort(string(condition.source_ids(:))),sel))
end
folder = fullfile(root,'results','sessions',sprintf('S%d',session));
assert(~isfolder(folder),'dip:SessionExists','此会话目录已存在，避免覆盖原始计时')
mkdir(folder)
blobs = fullfile(root,'local','blobs');
if ~isfolder(blobs), mkdir(blobs); end
dev = readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
warm = readFrozenMask(root,dev(dev.id==string(cfg.warm_id),:));
methods = ["seed","within_full","cross","matlab_geom","matlab_geom_within","exact"];
warmup = cell(2,numel(methods));
for pass=1:2
    for m=1:numel(methods)
        [t,e] = measureEncoding(warm,256,char(methods(m)),Inf,1);
        warmup{pass,m} = struct('status',t.status,'method',methods(m),'return_ms',t.return_ms, ...
            'received_ms',[e.received_ms],'attempted_rounds',numel(t.rounds));
        if ~ismember(methods(m),["seed","matlab_geom"])
            assert(~isempty(t.rounds),'dip:WarmupRound','预热没有进入搜索轮')
        end
        assert(~strcmp(t.status,'program_error'),'dip:Warmup','预热异常 %s',t.reason)
    end
end
meta = struct('session',session,'pid',feature('getpid'),'threads',maxNumCompThreads, ...
    'version',version,'lock',lock,'warm_id',cfg.warm_id,'warmup',{warmup}, ...
    'launch_to_warmup_end_ms',NaN);
launch = str2double(getenv('DIP_LAUNCH_UNIX_MS'));
if isfinite(launch),meta.launch_to_warmup_end_ms=posixtime(datetime('now','TimeZone','UTC'))*1000-launch; end
writeJson(fullfile(folder,'start.json'),meta)
for rep=1:2
    schedule = buildSchedule(cfg,sources,session,rep);
    path = fullfile(folder,sprintf('rep%d.jsonl',rep));
    total = 0;
    for j=1:size(schedule,1)
        row = sources(schedule{j,2},:);
        budget = schedule{j,3};
        list = schedule{j,4};
        clock = tic;
        raw = readFrozenMask(root,row);
        inputMs = toc(clock)*1000;
        records = cell(numel(list),1);
        for m=1:numel(list)
            [t,e] = measureEncoding(raw,budget,char(list(m)),200,cfg.max_rounds);
            disk = tic;
            for k=1:numel(e)
                bytes = e(k).bytes;
                digest = char(sha256Bytes(bytes));
                dest = fullfile(blobs,[digest '.pm3']);
                if ~isfile(dest)
                    fid = fopen([dest '.part'],'wb');
                    assert(fid>=0)
                    count = fwrite(fid,bytes,'uint8');
                    closed = fclose(fid);
                    assert(count==numel(bytes) && closed==0)
                    [ok,msg] = movefile([dest '.part'],dest);
                    assert(ok,'%s',msg)
                end
                e(k).sha256 = digest;
                assert(e(k).serialized_ms<=e(k).received_ms && e(k).received_ms<=t.return_ms)
            end
            diskMs = toc(disk)*1000;
            records{m} = struct('dataset',row.dataset,'id',row.id,'session',session,'rep',rep, ...
                'budget',budget,'method',list(m),'position',m,'input_ms',inputMs,'disk_ms',diskMs, ...
                'result',t,'events',rmfield(e,'bytes'));
        end
        fid = fopen(path,'a','n','UTF-8');
        assert(fid>=0)
        try
            for m=1:numel(records),fprintf(fid,'%s\n',jsonencode(records{m}));end
        catch err
            fclose(fid);
            rethrow(err)
        end
        assert(fclose(fid)==0)
        total=total+numel(records);
        if mod(j,50)==0, fprintf('S%d rep%d %d/%d blocks\n',session,rep,j,size(schedule,1));end
    end
    assert(total==2028)
end
writeJson(fullfile(folder,'complete.json'),struct('pid',meta.pid,'calls',4056,'freeze',lock))
end


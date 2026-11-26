function [obs,events,runs] = readJournals(root)
%从原始接收日志选择每个时限前最后一份完整文件
fields={'dataset','id','session','rep','budget','method'};
observed=cell(24336,18); emitted=cell(0,18); calls=cell(12168,14);
idx=0; run=0; ev=0;
frozen=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');
sourceKeys=frozen.dataset+"/"+frozen.id;
masks=containers.Map('KeyType','char','ValueType','any');
scores=containers.Map('KeyType','char','ValueType','any');
for sid=1:3
    folder=fullfile(root,'results','sessions',sprintf('S%d',sid));
    assert(isfile(fullfile(folder,'complete.json')),'dip:IncompleteSession','缺少完整会话 %d',sid)
    for rep=1:2
        fid=fopen(fullfile(folder,sprintf('rep%d.jsonl',rep)),'rt','n','UTF-8');
        closer=onCleanup(@() fclose(fid));
        line=fgetl(fid);
        while ischar(line)
            t=jsondecode(line);
            assert(t.session==sid && t.rep==rep)
            key={string(t.dataset),string(t.id),sid,rep,t.budget,string(t.method)};
            result=t.result; run=run+1;
            rings=result.rings; if isempty(rings),rings=NaN;end
            calls(run,:)=[key,{string(result.status),string(result.reason),rings,result.end_ms, ...
                result.return_ms,t.input_ms,t.disk_ms,t.position}];
            received=[];
            if ~isempty(t.events)
                received=[t.events.received_ms];
                assert(issorted(received) && received(end)<=result.return_ms)
                for e=reshape(t.events,1,[])
                    ev=ev+1;
                    emitted(ev,:)=[key,{e.round,e.xor,e.nbytes,e.serialized_ms,e.received_ms, ...
                        string(e.sha256),nanValue(e.donor),nanValue(e.receiver),nanValue(e.deleted_x), ...
                        nanValue(e.deleted_y),nanValue(e.inserted_x),nanValue(e.inserted_y)}];
                end
            end
            for deadline=[100 200]
                idx=idx+1;
                k=find(received<=deadline,1,'last');
                status=string(result.status);
                values={NaN,NaN,NaN,NaN,NaN,NaN,NaN,""};
                if ~isempty(k)
                    e=t.events(k);status="success";
                    source=string(t.dataset)+"/"+string(t.id);
                    cache=char(source+"/"+string(e.sha256));
                    if ~isKey(scores,cache)
                        if ~isKey(masks,char(source))
                            masks(char(source))=readFrozenMask(root,frozen(sourceKeys==source,:));
                        end
                        bytes=readBytes(fullfile(root,'local','blobs',[e.sha256 '.pm3']));
                        assert(strcmp(sha256Bytes(bytes),e.sha256) && numel(bytes)==e.nbytes)
                        scores(cache)=pixelScores(masks(char(source)),decodePM31(bytes));
                    end
                    s=scores(cache); assert(s.xor==e.xor)
                    values={e.nbytes,s.xor,s.fp,s.fn,s.iou,s.rmse,e.received_ms,string(e.sha256)};
                elseif result.return_ms>deadline || status=="success"
                    status="not_ready";
                end
                observed(idx,:)=[key,{deadline,status},values,{rings,result.return_ms}];
            end
            line=fgetl(fid);
        end
        clear closer
    end
end
assert(run==12168 && idx==24336)
obs=cell2table(observed,'VariableNames',[fields,{'deadline','status','nbytes','xor','fp','fn','iou','rmse','received_ms','sha256','rings','return_ms'}]);
runs=cell2table(calls,'VariableNames',[fields,{'status','reason','rings','search_end_ms','return_ms','input_ms','disk_ms','position'}]);
assert(height(unique(runs(:,fields)))==run)
events=cell2table(emitted,'VariableNames',[fields,{'round','xor','nbytes','serialized_ms','received_ms','sha256','donor','receiver','deleted_x','deleted_y','inserted_x','inserted_y'}]);
if isempty(events)
    for name=["dataset","id","method","sha256"],events.(name)=strings(0,1);end
    numbers=setdiff(string(events.Properties.VariableNames),["dataset","id","method","sha256"]);
    for name=numbers,events.(name)=zeros(0,1);end
end
end

function value=nanValue(x)
if isempty(x), value=NaN;else,value=x;end
end


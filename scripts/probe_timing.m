function probe_timing(label)
%只在已登记开发样本上比较进程、线程和缓存状态
root=fileparts(fileparts(mfilename('fullpath')));addpath(genpath(fullfile(root,'src')));
folder=fullfile(root,'results');launch=str2double(getenv('DIP_PROBE_START_UTC_MS'));
start=posixtime(datetime('now','TimeZone','UTC'))*1000;startup=start-launch;
threads=maxNumCompThreads;pid=feature('getpid');
if string(label)=="single",assert(threads==1);end
dev=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
clock=tic;raw=readFrozenMask(root,dev(dev.id=="Bengal_187",:));readMs=toc(clock)*1000;
toolboxMs=zeros(2,1);
for k=1:2
    clock=tic;cc=bwconncomp(raw,8);toolboxMs(k)=toc(clock)*1000;assert(cc.NumObjects>0);
end
methods=["seed","within_full","cross","matlab_geom","matlab_geom_within","exact"];
runs=cell(24,10);row=0;
for pass=1:4
    order=methods;if mod(pass,2)==0,order=fliplr(methods);end
    for pos=1:numel(order)
        [result,events]=measureEncoding(raw,256,char(order(pos)),200,8);row=row+1;
        assert(result.status=="success" && ~isempty(events),'DIP:ProbeFailure','Bengal_187 probe failed');
        runs(row,:)={pid,threads,pass,pos,order(pos),result.status,events(1).received_ms,result.end_ms,result.return_ms,numel(events)};
        if row==1,firstBytes=events(1).bytes;end
    end
end
[~,rings,parents]=decodePM31(firstBytes);clock=tic;received=NaN;
samples=300;latencies=zeros(samples,3);receiver=@receive;
for i=1:samples
    t0=toc(clock);bytes=packPM31(size(raw),rings,parents);t1=toc(clock);receiver(bytes);t2=toc(clock);
    latencies(i,:)=[t1-t0,received-t1,t2-t1]*1000;
    assert(isequal(bytes,firstBytes));
end
meta=table(string(label),pid,threads,startup,readMs,toolboxMs(1),toolboxMs(2),string(version),'VariableNames',...
    {'launch','pid','threads','launcher_to_function_ms','source_read_hash_ms','bwconncomp_first_ms','bwconncomp_second_ms','version'});
writetable(meta,fullfile(folder,"timing_probe_"+label+"_environment.csv"));
writetable(cell2table(runs,'VariableNames',{'pid','threads','pass','order_position','method','status','seed_received_ms','search_end_ms','return_ms','checkpoints'}),fullfile(folder,"timing_probe_"+label+"_encoders.csv"));
writetable(array2table(latencies,'VariableNames',{'pack_ms','dispatch_to_entry_ms','callback_roundtrip_ms'}),fullfile(folder,"timing_probe_"+label+"_callback.csv"));
    function receive(~)
        received=toc(clock);
    end
end

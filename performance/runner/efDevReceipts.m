function efDevReceipts(folder,calls)
%固定工作量按同源同会话同轮字节匹配，保留时刻差及边界内存快照
ev=readtable(fullfile(folder,'events.csv'),'TextType','string');
keys={'dataset','id','session','rep','budget','round'};fields={'received_ms','serialized_ms','interval_ms','sha256'};
all={};rows=cell(0,11);
for m=["cross","within","geom","geom_within"]
    a=ev(ev.method=="old_"+m,[keys,fields]);b=ev(ev.method=="fast_"+m,[keys,fields]);
    a=sortrows(a,keys);b=sortrows(b,keys);assert(isequal(a(:,keys),b(:,keys)) && isequal(a.sha256,b.sha256))
    t=a(:,keys);t.method=repmat(m,height(t),1);t.sha256=a.sha256;
    t.old_ms=a.received_ms;t.fast_ms=b.received_ms;t.delta_ms=b.received_ms-a.received_ms;
    t.old_interval_ms=a.interval_ms;t.fast_interval_ms=b.interval_ms;
    t.old_serialized_ms=a.serialized_ms;t.fast_serialized_ms=b.serialized_ms;all{end+1}=t;
    for k=unique(t.round).'
        z=t(t.round==k,:);[g,id,~]=findgroups(z.id,z.session);d=splitapply(@mean,z.delta_ms,g);
        g=findgroups(id);per=splitapply(@mean,d,g);
        rows(end+1,:)={m,k,height(z),numel(per),mean(per),median(z.delta_ms), ...
            nnz(z.delta_ms<0),nnz(z.delta_ms==0),nnz(z.delta_ms>0),median(z.old_interval_ms),median(z.fast_interval_ms)};
    end
end
writetable(vertcat(all{:}),fullfile(folder,'matched_files.csv'));
writetable(cell2table(rows,'VariableNames',{'method','round','n_events','n_sources','source_mean_delta_ms', ...
    'median_delta_ms','earlier','tied','later','old_median_interval_ms','fast_median_interval_ms'}),fullfile(folder,'receipt_summary.csv'))
[g,method]=findgroups(calls.method);
lo=splitapply(@min,calls.memory_before,g);hi=splitapply(@max,calls.memory_after,g);
delta=splitapply(@median,calls.memory_after-calls.memory_before,g);
writetable(table(method,lo,hi,delta,'VariableNames',{'method','min_before_bytes','max_after_bytes','median_after_minus_before_bytes'}), ...
    fullfile(folder,'memory_samples.csv'))
end

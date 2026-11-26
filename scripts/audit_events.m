function audit_events(root)
%以接收方实际拿到的两个相邻文件逐顶点验证每个动作
folder=fullfile(root,'results');
ev=readtable(fullfile(folder,'events.csv'),'TextType','string');
runs=readtable(fullfile(folder,'runs.csv'),'TextType','string');
key={'dataset','id','session','rep','budget','method'};
ev=sortrows(ev,[key,{'round'}]);
[g,identity]=findgroups(ev(:,key));
assert(issorted(g))
state=containers.Map('KeyType','char','ValueType','any');
checks=cell(0,17);
start=[1;find(diff(g))+1];
stop=[start(2:end)-1;height(ev)];
if isempty(ev),start=[];stop=[];end
first=ev(start,:);
assert(all(first.round==0) && all(isnan(first.donor)))
for j=1:height(identity)
    rr=start(j):stop(j); chain=ev(rr,:);
    assert(chain.round(1)==0 && all(diff(chain.round)==1) && ...
        all(diff(chain.received_ms)>=0) && all(diff(chain.xor)<0) && all(chain.nbytes==chain.nbytes(1)))
    assert(all(chain.serialized_ms<=chain.received_ms))
    for k=2:height(chain)
        a=chain(k-1,:);b=chain(k,:);
        old=loadRings(a.sha256);new=loadRings(b.sha256);
        counts=cellfun(@(p)size(p,1),old);after=cellfun(@(p)size(p,1),new);
        donor=b.donor+1;receiver=b.receiver+1;
        assert(sum(counts)==sum(after) && all(after>=3))
        diffCount=zeros(size(counts));diffCount(donor)=diffCount(donor)-1;diffCount(receiver)=diffCount(receiver)+1;
        assert(isequal(after-counts,diffCount))
        removed=[b.deleted_x b.deleted_y];added=[b.inserted_x b.inserted_y];
        assert(isequal(setdiff(old{donor},new{donor},'rows'),removed) && ...
            isequal(setdiff(new{receiver},old{receiver},'rows'),added))
        for t=1:numel(old)
            x=old{t};y=new{t};
            if t==donor,x(ismember(x,removed,'rows'),:)=[];end
            if t==receiver,y(ismember(y,added,'rows'),:)=[];end
            assert(isequal(x,y),'dip:Order','未改动的顶点顺序发生变化')
        end
        if contains(b.method,"within"),assert(donor==receiver);end
        checks(end+1,:)=[table2cell(b(:,key)),{b.round,b.donor,b.receiver,removed(1),removed(2), ...
            added(1),added(2),a.xor,b.xor,b.nbytes,b.received_ms}];
    end
end
%单环时两套候选机制等同，只比较双方真正完成的同轮文件
single=innerjoin(ev,runs(runs.rings==1,key),'Keys',key);
match={'dataset','id','session','rep','budget','round'};
left=single(single.method=="cross",[match,{'sha256','received_ms'}]);
right=single(single.method=="within_full",[match,{'sha256','received_ms'}]);
left=renamevars(left,{'sha256','received_ms'},{'cross_sha','cross_ms'});
right=renamevars(right,{'sha256','received_ms'},{'within_sha','within_ms'});
negative=innerjoin(left,right,'Keys',match);
assert(all(negative.cross_sha==negative.within_sha),'dip:SingleRing','共同完成的单环轮次字节不同')
writetable(negative,fullfile(folder,'single_ring_control.csv'))
out=cell2table(checks,'VariableNames',[key,{'round','donor','receiver','removed_x','removed_y','inserted_x', ...
    'inserted_y','xor_before','xor_after','nbytes','received_ms'}]);
writetable(out,fullfile(folder,'accepted_transitions.csv'))
assert(height(first)==nnz(runs.status=="success") || any(runs.status=="program_error"))
succeeded=runs(runs.status=="success",key);
assert(height(innerjoin(succeeded,first(:,key),'Keys',key))==height(succeeded))
assert(~any(ismember(ev.method,["seed","matlab_geom"]) & ev.round~=0))
e=first(:,[key,{'received_ms'}]);
run=outerjoin(runs,e,'Keys',key,'MergeKeys',true,'Type','left');
[g,tab]=findgroups(run(:,{'dataset','budget','method'}));
tab.calls=splitapply(@numel,run.rep,g);
tab.ever_received=splitapply(@(v)nnz(isfinite(v)),run.received_ms,g);
for f=["received_ms","return_ms","search_end_ms","disk_ms","input_ms"]
    for q=[50 90 99]
        tab.(f+"_p"+q)=splitapply(@(v)percentile(v,q),run.(f),g);
    end
end
writetable(tab,fullfile(folder,'time_distributions.csv'))

    function rings=loadRings(digest)
        name=char(digest);
        if ~isKey(state,name)
            [~,values]=decodePM31(readBytes(fullfile(root,'local','blobs',digest+".pm3")));
            state(name)=values;
        end
        rings=state(name);
    end
end

function value=percentile(v,q)
v=v(isfinite(v));value=NaN;
if ~isempty(v),value=prctile(v,q);end
end

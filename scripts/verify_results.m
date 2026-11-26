function verify_results(root)
%独立读原始字节、追溯接收事件，再按像素与区域复算
folder=fullfile(root,'results');
obs=readtable(fullfile(folder,'observations.csv'),'TextType','string');
ev=readtable(fullfile(folder,'events.csv'),'TextType','string');
runs=readtable(fullfile(folder,'runs.csv'),'TextType','string');
roster=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');
settings=jsondecode(fileread(fullfile(root,'configs','confirm.json')));
key={'dataset','id','session','rep','budget','method'};
assert(height(unique(obs(:,[key,{'deadline'}])))==24336 && height(obs)==24336 && height(runs)==12168)
has=obs.status=="success";assert(all(isfinite(obs.xor(has))) && all(isnan(obs.xor(~has))))
assert(all(obs.received_ms(has)<=obs.deadline(has)) && all(obs.nbytes(has)<=obs.budget(has)))
regions=cell(0,13); images=cell(0,12); groups=cell(height(roster),4);
for i=1:height(roster)
    row=roster(i,:);raw=readFrozenMask(root,row);
    [fullRings,parents]=extractRings(raw);
    assert(isequal(raw,renderRings(size(raw),fullRings)))
    groups(i,:)={row.dataset,row.id,numel(parents),nnz(raw)};
    ref=digitalLayout(raw);
    a=ev(ev.id==row.id & ev.dataset==row.dataset,:);
    o=obs(obs.id==row.id & obs.dataset==row.dataset,:);
    assert(all(o.rings(o.status=="success")==numel(parents)))
    budgets=256;if row.supplement,budgets=[128 256 512];end
    expected=6*2*(5*numel(budgets)+double(row.supplement));
    assert(height(o)==expected)
    for b=budgets
        methods=["cross","within_full","seed","matlab_geom","matlab_geom_within"];
        if b==256 && row.supplement,methods(end+1)="exact";end
        for m=methods,assert(nnz(o.budget==b & o.method==m)==12);end
    end
    for digest=unique(a.sha256).'
        bytes=readBytes(fullfile(root,'local','blobs',digest+".pm3"));
        assert(strcmp(sha256Bytes(bytes),digest))
        [mask,rings,par]=decodePM31(bytes); assert(isequal(par,parents))
        lengthBytes=10+4*numel(rings)+4*sum(cellfun(@(v)size(v,1),rings));
        assert(numel(bytes)==lengthBytes && isequal(packPM31(size(raw),rings,par),bytes))
        [reason,rr]=structureMatch(ref,digitalLayout(mask));assert(strcmp(reason,'ok'))
        for j=1:size(rr,1)
            regions(end+1,:)=[{row.dataset,row.id,digest},num2cell(rr(j,:))];
        end
        fp=nnz(mask & ~raw);fn=nnz(raw & ~mask);uni=nnz(mask|raw);
        iou=1;if uni,iou=(uni-fp-fn)/uni;end
        rmse=sqrt((fp+fn)/numel(raw));
        h=a.sha256==digest;
        assert(all(a.nbytes(h)==lengthBytes & a.xor(h)==fp+fn))
        hit=o.status=="success" & strcmp(o.sha256,digest);
        assert(all(o.xor(hit)==fp+fn & o.fp(hit)==fp & o.fn(hit)==fn & ...
            abs(o.iou(hit)-iou)<2e-12 & abs(o.rmse(hit)-rmse)<2e-12))
        bf=boundaryF(raw,mask);
        images(end+1,:)=[{row.dataset,row.id,digest,lengthBytes,fp+fn,fp,fn,iou,rmse},num2cell(bf)];
    end
    for j=1:height(o)
        hits=a(a.session==o.session(j) & a.rep==o.rep(j) & a.method==o.method(j) ...
            & a.budget==o.budget(j) & a.received_ms<=o.deadline(j),:);
        if isempty(hits)
            assert(o.status(j)~="success")
        else
            assert(o.status(j)=="success" && o.sha256(j)==hits.sha256(end) && o.received_ms(j)==hits.received_ms(end) ...
                && o.nbytes(j)==hits.nbytes(end) && o.xor(j)==hits.xor(end))
        end
    end
    for b=budgets
        dp=a(a.budget==b & a.round==0 & ismember(a.method,["within_full","cross","seed","exact"]),:);
        geom=a(a.budget==b & a.round==0 & startsWith(a.method,"matlab_geom"),:);
        assert(numel(unique(dp.sha256))<=1 && numel(unique(geom.sha256))<=1)
    end
end
g=cell2table(groups,'VariableNames',{'dataset','id','rings','foreground'});
writetable(g,fullfile(folder,'source_structure.csv'))
writetable(cell2table(regions,'VariableNames',{'dataset','id','sha256','kind','reference_id','decoded_id','reference_area', ...
    'decoded_area','intersection','recall','precision','area_ratio','iou'}),fullfile(folder,'regions.csv'))
writetable(cell2table(images,'VariableNames',{'dataset','id','sha256','nbytes','xor','fp','fn','iou','rmse','bf1','bf2','bf3'}), ...
    fullfile(folder,'blob_metrics.csv'))
pids=zeros(1,3);
for n=1:3
    start=jsondecode(fileread(fullfile(folder,'sessions',sprintf('S%d',n),'start.json')));
    pids(n)=start.pid; assert(start.threads==1 && strcmp(start.warm_id,settings.warm_id))
end
assert(numel(unique(pids))==3)
writeJson(fullfile(folder,'verification.json'),struct('sources',height(g),'calls',height(runs),'observations',height(obs), ...
    'received_events',height(ev),'replayed_source_files',size(images,1),'regions',size(regions,1),'pid',pids))
end

function f=boundaryF(a,b)
%内边界取三乘三全邻域，四周补背景后计算欧氏距离容差
e=a & conv2(double(a),ones(3),'same')<9;
p=b & conv2(double(b),ones(3),'same')<9;
if ~any(e,'all') && ~any(p,'all'),f=[1 1 1];return;end
toRef=bwdist(e); toOut=bwdist(p); f=zeros(1,3);
for r=1:3
    prec=nnz(toRef(p)<=r)/max(1,nnz(p));rec=nnz(toOut(e)<=r)/max(1,nnz(e));
    if prec+rec>0,f(r)=2*prec*rec/(prec+rec);end
end
end


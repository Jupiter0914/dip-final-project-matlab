function stats=verifyExploration(root,manifest,out)
%只从已写入文件重新识别尺寸、顶点和像素结果
read=@(file) readtable(fullfile(out,file),'TextType','string');
single=read('poly02_trials.csv'); pso=read('pso_trials.csv');
controls=read('within_candidate_controls.csv'); allocation=read('allocation.csv');
assert(height(single)==54 && height(pso)==27 && height(controls)==216);
assert(height(unique(single(:,{'id','k','method'})))==height(single));
assert(height(unique(pso(:,{'id','k','seed'})))==height(pso));
assert(height(unique(controls(:,{'id','method'})))==height(controls));
stdGold=readtable(fullfile(root,'data','compat','dev_exterior.csv'),'TextType','string');
assert(isequal(manifest.id,stdGold.id));
oldShared=["american_pit_bull_terrier_148","yorkshire_terrier_106","shiba_inu_142","Bengal_148"];
rawById=cell(height(manifest),1); extById=cell(height(manifest),1);
for i=1:height(manifest)
    rawById{i}=readFrozenMask(root,manifest(i,:));
    [extById{i},dense]=pol1Exterior(rawById{i});
    assert(strcmp(pixelHash(extById{i}),stdGold.pixel_sha256(i)) && size(dense,1)==stdGold.vertices(i),'DIP:OuterMismatch','Exterior differs for %s',manifest.id(i));
end
for i=1:height(single)
    if single.status(i)~="success", assert(isnan(single.xor(i))); continue; end
    target=extById{manifest.id==single.id(i)};
    bytes=readBytes(fullfile(out,'pol1',single.sha256(i)+".poly"));
    pred=pol1Decode(bytes);
    assert(strcmp(sha256Bytes(bytes),single.sha256(i)) && numel(bytes)==single.bytes(i));
    assert(nnz(pred & ~target)==single.fp(i) && nnz(target & ~pred)==single.fn(i));
    assert(nnz(pred~=target)==single.xor(i) && abs(pol1BoundaryScore(target,pred,2)-single.bf2(i))<1e-12);
end
for i=1:height(pso)
    if pso.status(i)~="success", assert(isnan(pso.xor(i))); continue; end
    target=extById{manifest.id==pso.id(i)};
    file=sprintf('%s-K%d-seed%d.poly',pso.id(i),pso.k(i),pso.seed(i));
    bytes=readBytes(fullfile(out,'pso',file)); mask=pol1Decode(bytes);
    assert(numel(bytes)==pso.bytes(i) && strcmp(sha256Bytes(bytes),pso.sha256(i)));
    assert(nnz(mask~=target)==pso.xor(i));
end
for i=1:height(controls)
    if controls.status(i)~="success", assert(isnan(controls.final_xor(i))); continue; end
    raw=rawById{manifest.id==controls.id(i)};
    bytes=readBytes(fullfile(out,'control_blobs',controls.sha256(i)+".pm3")); mask=decodePM31(bytes);
    assert(numel(bytes)==controls.bytes(i) && strcmp(sha256Bytes(bytes),controls.sha256(i)));
    assert(nnz(mask~=raw)==controls.final_xor(i) && strcmp(structureMatch(digitalLayout(raw),digitalLayout(mask)),'ok'));
end
stats=struct('single_rows',height(single),'single_success',nnz(single.status=="success"), ...
    'pso_rows',height(pso),'pso_success',nnz(pso.status=="success"), ...
    'control_rows',height(controls),'control_success',nnz(controls.status=="success"), ...
    'allocation_rows',height(allocation),'repair_triggers',nnz(allocation.dp_reason~="ok" & allocation.dp_reason~="unavailable"), ...
    'legal_allocation_pairs',sum(allocation.legal_pairs),'pair_rank_disagreements',sum(allocation.ranking_disagreements), ...
    'allocation_pool_success',nnz(allocation.legal_pool>0),'validated_dev_exteriors',height(manifest));
guard=single(single.method=="post_guard",:); geo=single(single.method=="geometry",:);
[ok,idx]=ismember(guard.id+"|"+guard.k,geo.id+"|"+geo.k); assert(all(ok));
geo=geo(idx,:); use=guard.status=="success" & geo.status=="success";
stats.guard_comparable=nnz(use); stats.guard_bf2_violations=nnz(guard.bf2(use)<geo.bf2(use)-1e-12);
stats.guard_xor_increases=nnz(guard.xor(use)>geo.xor(use));
assert(stats.guard_bf2_violations==0 && stats.guard_xor_increases==0);
%只在本次文件复算后读取历史摘要，分别记录开发夹具的文件与像素一致性
polyOld=readtable(fullfile(root,'data','compat','historical_pol1.csv'),'TextType','string');
psoOld=readtable(fullfile(root,'data','compat','historical_author_pso.csv'),'TextType','string');
polyKeys=single.id+"|"+single.k+"|"+single.method;
oldKeys=polyOld.id+"|"+polyOld.k+"|"+polyOld.method;
[hit,idx]=ismember(polyKeys,oldKeys); assert(all(hit));
stats.historical_pol1_wire_matches=nnz(single.sha256==polyOld.blob_sha256(idx));
stats.historical_pol1_xor_matches=nnz(single.xor==polyOld.xor(idx));
oldKeys=psoOld.id+"|"+psoOld.k+"|"+psoOld.seed;
[hit,idx]=ismember(pso.id+"|"+pso.k+"|"+pso.seed,oldKeys); assert(all(hit));
stats.historical_pso_wire_matches=nnz(pso.sha256==psoOld.blob_sha256(idx));
stats.historical_pso_xor_matches=nnz(pso.xor==psoOld.xor(idx));
stats.old_shared_development_ids=oldShared;
groups=[true(height(controls),1),ismember(controls.id,oldShared)];
summary=struct([]);
for g=1:2
    rows=controls(groups(:,g),:); cross=rows(rows.method=="cross" & rows.rings>=2,:);
    for base=["within_old","within_full_oldtri","within_full","cross_oldtri","cross_full_oldtri"]
        d=rows(rows.method==base,:); [ok,ix]=ismember(cross.id,d.id); assert(all(ok)); d=d(ix,:);
        use=d.status=="success" & cross.status=="success" & d.bytes==cross.bytes;
        gain=d.final_xor(use)-cross.final_xor(use);
        summary=[summary;struct('group',g,'baseline',base,'multi_sources',height(cross),'paired',numel(gain), ...
            'mean_xor_gain',mean(gain),'wins',nnz(gain>0),'ties',nnz(gain==0),'losses',nnz(gain<0))];
    end
end
writetable(struct2table(summary),fullfile(out,'two_round_pairs.csv'));
fid=fopen(fullfile(out,'audit_summary.json'),'w','n','UTF-8');
guardFile=onCleanup(@() fclose(fid)); fprintf(fid,'%s',jsonencode(stats,'PrettyPrint',true));
end

function b=readBytes(path)
fid=fopen(path,'rb'); assert(fid>=0,'DIP:MissingBlob','Missing exploration blob');
guard=onCleanup(@() fclose(fid)); b=fread(fid,Inf,'*uint8')';
end

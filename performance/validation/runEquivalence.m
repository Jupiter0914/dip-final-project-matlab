function receipt=runEquivalence(scope,label,shard,nShards)
%在开发与合成轨迹通过之后，只对已锁定内核运行旧确认源回归
scope=string(scope); label=string(label);
if nargin<3,shard=1;nShards=1;end
assert(nShards==1 || (scope=="old300" && nShards==2));assert(ismember(shard,1:nShards));
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(root,'src')));
selector=label;if scope=="old300",selector="old300";end
stamp=validationKernel(root,selector);
hasDelta=isfile(fullfile(fileparts(which('efMeasure')),'efSingleChanges.m'));
assert(maxNumCompThreads==1 && ismember(scope,["dev","old300","fixtures"]));
T=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
assert(height(T)==36 && all(T.official=="trainval"));
if scope=="old300"
    path=fullfile(root,'configs','published_kernel.json');L=jsondecode(fileread(path));
    for k=1:numel(L.files)
        assert(strcmp(sha256Bytes(readBytes(fullfile(root,L.files(k).path))),L.files(k).sha256),'EF:Freeze','Selected kernel hash differs');
    end
    T=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');
    assert(height(T)==300 && nnz(T.dataset=="Oxford")==200 && nnz(T.dataset=="LEMS")==100);
    stamp.public_source_manifest=true;
    stamp.selected_lock_sha256=string(sha256Bytes(readBytes(path)));
    if nShards==2
        T=T(shard:2:end,:);label=label+"/shard"+shard;
    end
end
out=fullfile(root,'perf_results',label); if ~isfolder(out), mkdir(out); end
writeJson(fullfile(out,'kernel_stamp.json'),stamp);
if scope=="dev" || scope=="fixtures"
    [names,masks]=validationFixtures();
    if scope=="fixtures",T=T([],:);end
    special=checkSpecialCases(root,out);
    if hasDelta,special.global_edge_cases=checkAdversarialPixels(out);end
else
    names=strings(0,1);masks=cell(0,1);special=struct();
end
nFixture=numel(names); names=[names;T.dataset+"/"+T.id]; methods=["within_full","cross","matlab_geom","matlab_geom_within"];
setNames=[repmat("synthetic",nFixture,1);T.dataset];
calls=cell(numel(names)*4,9); q=0; rounds=cell(numel(names),1);points=cell(numel(names),1);
fields={'id','budget','method','round','donors','receivers','eligible_pairs','top_pairs','full_checks', ...
    'accepted','cross','triangle','rebuilt_rings','reused_rings','xor_before','xor_after','trace_sha256','fast_trace_sha256','reference_wire','fast_wire'};
if hasDelta,fields=[fields,{'pixel_checked_edits','pixel_ids_compared','fallbacks'}];end
for i=1:numel(names)
    if i<=nFixture,raw=masks{i};else,raw=readFrozenMask(root,T(i-nFixture,:));end
    budget=256;
    if scope=="fixtures" && ismember(names(i),["near_components","diagonal_neck"]),budget=62;end
    if scope=="fixtures" && names(i)=="island_in_hole",budget=26;end
    batch=cell(0,numel(fields)); checkpoints=cell(0,22);
    for method=methods
        q=q+1;
        [calls(q,:),rs,ps]=validateTrajectory(raw,names(i),budget,method,out,scope~="dev",root);
        batch=[batch;rs];checkpoints=[checkpoints;ps];
    end
    rounds{i}=batch;points{i}=checkpoints;
    if mod(i,50)==0 || (i>nFixture && mod(i,5)==0) || i==numel(names)
        fprintf('Equivalence %s %d/%d sources\n',scope,i,numel(names));
        progress=struct('scope',scope,'tested',i,'expected',numel(names),'id',names(i));
        writeJson(fullfile(out,'equivalence_progress.json'),progress);
    end
end
C=cell2table(calls,'VariableNames',{'id','budget','method','status','reason','checkpoints','rounds','initial_sha256','final_sha256'});
C.source_set=repelem(setNames,4);
R=cell2table(vertcat(rounds{:}),'VariableNames',fields);
P=cell2table(vertcat(points{:}),'VariableNames',{'id','budget','method','round','reference_sha256','fast_sha256', ...
    'reference_bytes','fast_bytes','reference_xor','fast_xor','ref_donor','ref_receiver','ref_deleted_x','ref_deleted_y', ...
    'ref_inserted_x','ref_inserted_y','fast_donor','fast_receiver','fast_deleted_x','fast_deleted_y','fast_inserted_x','fast_inserted_y'});
writetable(P,fullfile(out,'equivalence_checkpoints.csv'));
writetable(C,fullfile(out,'equivalence_calls.csv'));writetable(R,fullfile(out,'equivalence_rounds.csv'));
receipt=struct('passed',true,'scope',scope,'sources',height(T),'synthetic',nFixture,'calls',height(C), ...
    'rounds',height(R),'outputs',sum(C.checkpoints),'single_deletions',sum(R.donors),'single_insertions',sum(R.receivers), ...
    'legal_pairs',sum(R.eligible_pairs),'top_pairs',sum(R.top_pairs),'actual_full_checks',sum(R.full_checks), ...
    'reused_rings',sum(R.reused_rings),'rebuilt_rings',sum(R.rebuilt_rings),'accepted_cross',nnz(R.cross), ...
    'accepted_within',nnz(R.accepted & ~R.cross),'accepted_triangle',nnz(R.triangle),'special',special, ...
    'mismatches',0,'version',version,'threads',maxNumCompThreads);
receipt.shard=shard;receipt.n_shards=nShards;
if hasDelta
    receipt.pixel_checked_edits=sum(R.pixel_checked_edits);receipt.pixel_ids_compared=sum(R.pixel_ids_compared);receipt.fallbacks=sum(R.fallbacks);
    assert(receipt.pixel_checked_edits==receipt.single_deletions+receipt.single_insertions && receipt.fallbacks>=0);
end
if nShards==1 && scope=="dev",assert(receipt.accepted_cross>0 && receipt.accepted_within>0 && receipt.reused_rings>0);end
writeJson(fullfile(out,'semantic_measurements.json'),receipt);
finalizeEquivalence(label,root);disp(receipt);
end

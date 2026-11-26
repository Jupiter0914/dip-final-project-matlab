function result=replayEquivalence(label,root,record)
%不调用任何搜索函数，从已存的逐轮表和逐调用表重建核对数量
if nargin<2,root=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(genpath(fullfile(root,'src')));
out=fullfile(root,'perf_results',label);
C=readtable(fullfile(out,'equivalence_calls.csv'),'TextType','string');
R=readtable(fullfile(out,'equivalence_rounds.csv'),'TextType','string');
if nargin<3,record=jsondecode(fileread(fullfile(out,'equivalence.json')));end
if string(record.scope)=="old300"
    lock=fullfile(root,'performance','selected_kernel.json');
    stamp=jsondecode(fileread(fullfile(out,'kernel_stamp.json')));
    if isfield(stamp,'public_source_manifest') && stamp.public_source_manifest
        lock=fullfile(root,'configs','published_kernel.json');
    end
    assert(strcmp(sha256Bytes(readBytes(lock)),stamp.selected_lock_sha256),'EF:Freeze','Selected kernel receipt has changed');
    for j=1:numel(stamp.files)
        assert(strcmp(sha256Bytes(readBytes(fullfile(root,stamp.files(j).path))),stamp.files(j).sha256),'EF:Freeze','Kernel source hash mismatch');
    end
end
keys={'id','budget','method'};
assert(height(unique(C(:,keys)))==height(C) && height(unique(R(:,[keys,{'round'}])))==height(R));
allowed=["within_full","cross","matlab_geom","matlab_geom_within"];
[G,~]=findgroups(C.id);assert(all(splitapply(@numel,C.method,G)==4) && all(ismember(C.method,allowed)));
%使用字符串键将每轮挂接回唯一的调用，同时保留没有输出或自然零轮的调用
keyC=C.id+"|"+C.budget+"|"+C.method; keyR=R.id+"|"+R.budget+"|"+R.method;
[has,idx]=ismember(keyR,keyC); assert(all(has)); n=height(C);
nRounds=accumarray(idx,1,[n 1]); nAccepted=accumarray(idx,double(R.accepted),[n 1]);
assert(isequal(C.rounds,nRounds) && isequal(C.checkpoints,nAccepted+double(C.status=="success")));
assert(all(R.top_pairs==min(24,R.eligible_pairs)) && all(R.full_checks<=R.top_pairs));
assert(all(R.xor_after(R.accepted~=0)<R.xor_before(R.accepted~=0)) && all(R.xor_after(R.accepted==0)==R.xor_before(R.accepted==0)));
assert(all(strlength(R.trace_sha256)==64));
for k=1:height(C)
    a=R(idx==k,:);if ~isempty(a)
        assert(isequal(a.round(:),(1:height(a))') && all(a.xor_before(2:end)==a.xor_after(1:end-1)));
        assert(all(a.accepted(1:end-1)) && a.round(end)<=8);
    end
    if C.checkpoints(k)>0
        assert(strlength(C.initial_sha256(k))==64 && strlength(C.final_sha256(k))==64);
    end
end
result=struct('calls',n,'rounds',height(R),'outputs',sum(C.checkpoints),'single_deletions',sum(R.donors), ...
    'single_insertions',sum(R.receivers),'legal_pairs',sum(R.eligible_pairs),'top_pairs',sum(R.top_pairs), ...
    'actual_full_checks',sum(R.full_checks),'reused_rings',sum(R.reused_rings),'rebuilt_rings',sum(R.rebuilt_rings), ...
    'accepted_cross',nnz(R.cross),'accepted_within',nnz(R.accepted & ~R.cross),'accepted_triangle',nnz(R.triangle));
if ismember('pixel_checked_edits',R.Properties.VariableNames)
    result.pixel_checked_edits=sum(R.pixel_checked_edits);result.pixel_ids_compared=sum(R.pixel_ids_compared);result.fallbacks=sum(R.fallbacks);
    assert(all(R.pixel_checked_edits==R.donors+R.receivers) && all(R.fallbacks>=0 & R.fallbacks<=R.pixel_checked_edits));
end
fields=fieldnames(result);
for i=1:numel(fields),assert(isequal(double(result.(fields{i})),double(record.(fields{i}))),'EF:Replay','Recomputed %s differs',fields{i});end
result.sources=numel(unique(C.id(C.source_set~="synthetic"))); result.synthetic=numel(unique(C.id(C.source_set=="synthetic")));
assert(result.sources==record.sources && result.synthetic==record.synthetic);
if ismember('reference_wire',R.Properties.VariableNames)
    assert(all(R.reference_wire==R.fast_wire) && all(R.trace_sha256==R.fast_trace_sha256));
    result.compared_round_wire_hashes=height(R);result.compared_round_trace_hashes=height(R);
    for k=1:height(C)
        a=R(idx==k,:);if ~isempty(a),assert(a.reference_wire(end)==C.final_sha256(k));end
    end
end
result.source_calls_sha256=sha256Bytes(readBytes(fullfile(out,'equivalence_calls.csv')));
result.source_rounds_sha256=sha256Bytes(readBytes(fullfile(out,'equivalence_rounds.csv')));
if isfile(fullfile(out,'equivalence_checkpoints.csv'))
    result.archive=replayValidationBlobs(root,out,C,string(record.scope));
end
result.passed=true; writeJson(fullfile(out,'equivalence_replay.json'),result);
end

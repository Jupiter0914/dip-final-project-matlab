function result=replayValidationBlobs(root,out,C,scope)
%每个源独立读取掩模，再按文件摘要去重重画所有实际接收的字节
P=readtable(fullfile(out,'equivalence_checkpoints.csv'),'TextType','string');
assert(height(P)==sum(C.checkpoints));
ck=C.id+"|"+C.budget+"|"+C.method; pk=P.id+"|"+P.budget+"|"+P.method;
[ok,ix]=ismember(pk,ck);assert(all(ok) && height(unique(P(:,{'id','budget','method','round'})))==height(P));
assert(isequal(accumarray(ix,1,[height(C) 1]),C.checkpoints));
assert(all(P.reference_sha256==P.fast_sha256) && all(P.reference_bytes==P.fast_bytes) && ...
    all(P.reference_xor==P.fast_xor) && all(P.reference_bytes<=P.budget));
for k=1:height(C)
    e=P(ix==k,:);if isempty(e),continue;end
    assert(isequal(e.round,(0:height(e)-1)') && all(diff(e.reference_xor)<0) && all(e.reference_bytes==e.reference_bytes(1)));
    assert(e.reference_sha256(1)==C.initial_sha256(k) && e.reference_sha256(end)==C.final_sha256(k));
end
if scope=="old300", roster="frozen";else,roster="dev";end
T=readtable(fullfile(root,'data','manifests',roster+".csv"),'TextType','string');
dataIds=T.dataset+"/"+T.id; [fixtureIds,fixtureMasks]=validationFixtures(); sources=unique(P.id); blobs=0;
moveColumns=["donor","receiver","deleted_x","deleted_y","inserted_x","inserted_y"];
hasActions=all(ismember("ref_"+moveColumns,string(P.Properties.VariableNames)));
verifiedMoves=0;
if hasActions
    for tag=moveColumns,assert(isequaln(P.("ref_"+tag),P.("fast_"+tag)));end
    assert(all(isnan(P.ref_donor(P.round==0))) && all(isnan(P.ref_receiver(P.round==0))));
end
for i=1:numel(sources)
    id=sources(i); sub=P(P.id==id,:); states=containers.Map('KeyType','char','ValueType','any');
    j=find(dataIds==id,1);
    if isempty(j), raw=fixtureMasks{fixtureIds==id};else,raw=readFrozenMask(root,T(j,:));end
    ref=digitalLayout(raw); [~,parents]=extractRings(raw);
    for digest=unique(sub.reference_sha256)'
        path=fullfile(root,'local','perf','validation_blobs',digest+".pm3");
        bytes=readBytes(path); assert(strcmp(sha256Bytes(bytes),digest));
        [mask,rings,par]=decodePM31(bytes); count=nnz(mask~=raw); group=sub.reference_sha256==digest;
        assert(isequal(size(mask),size(raw)) && isequal(par,parents) && isequal(packPM31(size(raw),rings,par),bytes));
        assert(all(sub.reference_bytes(group)==numel(bytes) & sub.reference_xor(group)==count));
        assert(strcmp(structureMatch(ref,digitalLayout(mask)),'ok')); blobs=blobs+1;
        if hasActions,states(char(digest))=rings;end
    end
    if hasActions
        methods=unique(sub.method);
        for m=methods'
            chain=sortrows(sub(sub.method==m,:),'round');
            for j=2:height(chain)
                old=states(char(chain.reference_sha256(j-1)));new=states(char(chain.reference_sha256(j)));
                checkMove(old,new,chain(j,:));verifiedMoves=verifiedMoves+1;
            end
        end
    end
end
result=struct('replayed_checkpoints',height(P),'source_blob_pairs',blobs,'unique_files',numel(unique(P.reference_sha256)), ...
    'checkpoints_csv_sha256',string(sha256Bytes(readBytes(fullfile(out,'equivalence_checkpoints.csv')))));
if hasActions,result.replayed_moves=verifiedMoves;assert(verifiedMoves==nnz(P.round>0));end
end

function checkMove(old,new,row)
donor=row.ref_donor+1; receiver=row.ref_receiver+1;
removed=[row.ref_deleted_x row.ref_deleted_y]; inserted=[row.ref_inserted_x row.ref_inserted_y];
assert(numel(old)==numel(new) && ismember(donor,1:numel(old)) && ismember(receiver,1:numel(old)));
assert(isequal(setdiff(old{donor},new{donor},'rows'),removed) && isequal(setdiff(new{receiver},old{receiver},'rows'),inserted));
for t=1:numel(old)
    a=old{t};b=new{t};if t==donor,a(ismember(a,removed,'rows'),:)=[];end
    if t==receiver,b(ismember(b,inserted,'rows'),:)=[];end
    assert(isequal(a,b),'EF:Replay','Unchanged vertices differ in action replay');
end
end

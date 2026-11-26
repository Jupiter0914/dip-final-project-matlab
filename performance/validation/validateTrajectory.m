function [row,roundRows,points]=validateTrajectory(raw,id,budget,method,witnessFolder,compact,archiveRoot)
if nargin<6,compact=false;end
if nargin<7,archiveRoot="";end
points=cell(0,22);
hasDelta=isfile(fullfile(fileparts(which('efMeasure')),'efSingleChanges.m'));
%两个生产入口独立从输入运行，诊断只在这两次调用返回之后开始
[old,oe]=measureEncoding(raw,budget,char(method),Inf,8);
[fast,fe]=efMeasure(raw,budget,char(method),Inf,8);
steps=0; roundRows=cell(0,20+3*hasDelta); before=[]; after=[]; ref=[]; opt=[]; k=0;
try
    check(string(old.status)~="program_error" && string(fast.status)~="program_error",'program_error');
    check(strcmp(old.status,fast.status) && strcmp(old.reason,fast.reason),'terminal_status');
    check(isequaln(old.init,fast.init),'initial_allocation_attempts');
    check(isequaln(old.rounds,fast.rounds),'production_actions');
    check(numel(oe)==numel(fe),'checkpoint_count');
    finalHash=""; initialHash="";
    for i=1:numel(oe)
        check(isequaln(rmfield(oe(i),{'serialized_ms','received_ms'}), ...
            rmfield(fe(i),{'serialized_ms','received_ms'})),'production_checkpoint');
        finalHash=string(sha256Bytes(oe(i).bytes));
        if i==1, initialHash=finalHash; end
    end
    if strlength(archiveRoot)>0,points=archiveTrajectory(archiveRoot,id,budget,method,oe,fe);end
    if ~isempty(oe)
        prep=prepareMask(raw,budget);
        if startsWith(method,"matlab_geom")
            [state,~]=geometrySeed(prep);
        else
            [state,~]=allocationSeed(prep);
        end
        before=state; other=state; cache=[];
        check(isequal(packPM31(prep.shape,state.rings,prep.parents),oe(1).bytes),'traced_seed');
        for k=1:numel(old.rounds)
            search=method; if method=="matlab_geom_within",search="within_full";end
            if compact
                [next,actual,ref]=recordedReferenceRound(prep,state,char(search),old.rounds{k});
            else
                [next,actual,ref]=referenceRound(prep,state,char(search));
            end
            [new,action,cache,opt]=efStep(prep,other,char(search),cache);
            check(isequaln(actual,old.rounds{k}) && isequaln(action,fast.rounds{k}),'production_diagnostic_actions');
            check(isequaln(ref.donors,sortrows(opt.donors)),'all_deletions');
            check(isequaln(ref.receivers,sortrows(opt.receivers)),'all_insertions');
            deltaCounts=[];if hasDelta,deltaCounts=checkRoundFlips(prep,state,opt);end
            for r=1:numel(state.rings)
                [ok,expected]=ismember(state.rings{r},prep.dense{r},'rows');
                check(all(ok) && isequal(expected,opt.ringDenseIndices{r}),'ring_dense_indices');
                d=opt.donors(:,2)==r; e=opt.receivers(:,2)==r;
                check(isequal(opt.donorDenseIndices(d),expected(opt.donors(d,3))),'donor_dense_indices');
                [yes,idx]=ismember(opt.receivers(e,4:5),prep.dense{r},'rows');
                check(all(yes) && isequal(idx(:),opt.receiverDenseIndices(e)),'receiver_dense_indices');
            end
            check(isequal(ref.pairs,opt.pairs) && ref.eligible==opt.eligible,'eligible_and_top24_ties');
            check(isequaln(ref.additive,opt.additive),'joint_additive');
            check(isequal(ref.rank(:),opt.rank(:)) && isequal(ref.tested(:),opt.checked(:)),'final_check_order');
            check(isequaln(ref.xor(ref.tested),opt.checkedXor) && isequal(ref.reasons,opt.checkedReason),'actual_xor_and_rejections');
            %两边确切相同的候选坐标确定同一待测多边形，整图参考值在此逐一比对
            fx=zeros(size(ref.xor));
            for j=1:size(opt.pairs,1)
                m=opt.pairs(j,:); cand=replaceVertex(other.rings,m(2),m(3),m(4),m(5),m(6:7));
                if compact
                    n=ref.pairs(j,:); baseline=replaceVertex(state.rings,n(2),n(3),n(4),n(5),n(6:7));
                    check(isequal(cand,baseline),'all_joint_geometry');
                end
                %快速侧提案独立回填，不以相同点列或参考侧的已算分数替代实测
                pred=renderRings(prep.shape,cand); fx(j)=nnz(pred~=prep.raw);
            end
            check(isequal(fx,ref.xor),'all_joint_xor');
            if k==1, invalid=(1:numel(state.rings))'; version=zeros(size(invalid)); end
            check(isequal(opt.rebuiltRings(:),invalid(:)),'cache_rebuilt');
            expectedReuse=setdiff((1:numel(state.rings))',invalid);
            check(isequal(opt.reusedRings(:),expectedReuse(:)),'cache_reused');
            version(invalid)=version(invalid)+1; check(isequal(opt.ringVersion(:),version(:)),'cache_version');
            invalid=zeros(0,1); if action.accepted,invalid=unique([action.donor;action.receiver]+1);end
            check(isequal(opt.invalidatedRings(:),invalid(:)),'cache_invalidation');
            check(isequaln(next,new),'traced_resulting_state');
            after=next; wire=packPM31(prep.shape,next.rings,prep.parents);
            if actual.accepted
                check(isequal(wire,oe(k+1).bytes) && isequal(wire,fe(k+1).bytes),'traced_checkpoint');
            end
            %每轮保留全部单项及排序结果的摘要和计数，完整差异另存见证文件
            digest=signature(ref.donors,ref.receivers,ref.pairs,ref.additive,ref.xor,ref.rank,ref.tested,ref.reasons);
            fastDigest=signature(sortrows(opt.donors),sortrows(opt.receivers),opt.pairs,opt.additive,fx,opt.rank,opt.checked,opt.checkedReason);
            check(strcmp(digest,fastDigest),'round_signature');
            left=string(sha256Bytes(wire));right=string(sha256Bytes(packPM31(prep.shape,new.rings,prep.parents)));
            check(left==right,'round_wire');
            roundRows(end+1,:)=[{id,budget,method,k,size(ref.donors,1),size(ref.receivers,1),ref.eligible,size(ref.pairs,1), ...
                numel(ref.tested),actual.accepted,actual.cross,actual.triangle,numel(opt.rebuiltRings),numel(opt.reusedRings), ...
                state.d,next.d,string(digest),string(fastDigest),left,right},num2cell(deltaCounts)];
            before=next;state=next;other=new;steps=steps+1;
        end
        check(isequal(packPM31(prep.shape,state.rings,prep.parents),oe(end).bytes),'terminal_wire');
    end
    row={id,budget,method,string(old.status),string(old.reason),numel(oe),steps,initialHash,finalHash};
catch err
    if ~isfolder(witnessFolder),mkdir(witnessFolder);end
    path=fullfile(witnessFolder,'first_mismatch.mat');
    if ~isfile(path)
        frames=struct('function',{},'line',{});
        for z=1:numel(err.stack),frames(z)=struct('function',err.stack(z).name,'line',err.stack(z).line);end
        message=regexprep(string(err.message),'(?i)[A-Z]:[\\/][^\r\n''"]*','<local path>');
        failure=struct('identifier',string(err.identifier),'message',message,'stack',{frames});
        save(path,'id','method','budget','k','raw','old','fast','oe','fe','before','after','ref','opt','failure','-v7');
    end
    rethrow(err)
end
end

function digest=signature(d,r,p,a,x,rank,inspected,reasons)
values=struct('donors',d,'receivers',r,'pairs',p,'additive',a,'xor',x,'rank',rank(:),'checked',inspected(:),'reason',reasons(:));
digest=sha256Bytes(uint8(jsonencode(values)));
end

function check(ok,item)
if ~ok,error('EF:Mismatch','Trajectory mismatch: %s',item);end
end

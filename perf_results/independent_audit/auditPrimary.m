function result=auditPrimary(root)
%从原始会话逐行恢复两项主比较，汇总表只在最后用于核验
if nargin==0,root=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
out=fullfile(root,'perf_results','independent_audit');addpath(genpath(fullfile(root,'src')))
result=struct('status','failed');
try
    result=rebuild(root,out);
    claim=jsondecode(fileread(fullfile(root,'perf_results','output','formal_claims.json')));
    names={'fixed_cross_ratio','A_ci95','A_ci975','quality_sources','quality_pairs', ...
        'mean_xor_gain','B_ci95','B_ci975','coverage_difference','coverage_ci95', ...
        'all_three_sessions_positive','all_leave_one_out_positive','A_supported','B_supported'};
    difference=zeros(numel(names),1);pass=true(numel(names),1);
    for j=1:numel(names)
        a=double(result.(names{j}));b=double(claim.(names{j}));assert(numel(a)==numel(b))
        difference(j)=max(abs(a(:)-b(:)));pass(j)=difference(j)<=1e-11;
    end
    writetable(table(string(names(:)),difference,pass,'VariableNames',{'claim_field','max_abs_diff','match'}),fullfile(out,'comparison.csv'))
    assert(all(pass),'IndAudit:Mismatch','Independent primary estimates differ from the formal analysis')
    result.status='pass';result.max_abs_diff=max(difference);
    writeJson(fullfile(out,'receipt.json'),result)
catch err
    result.status='failed';result.error_id=err.identifier;result.message=err.message;
    writeJson(fullfile(out,'receipt.json'),result);rethrow(err)
end
end

function result=rebuild(root,out)
m=readtable(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv'),'TextType','string');
m=sortrows(m,'id');N=height(m);assert(N==200 && nnz(m.fixed48)==48 && numel(unique(m.id))==N)
mask=cell(N,1);binary=containers.Map('KeyType','char','ValueType','any');
for i=1:N
    file=fullfile(root,m.file(i)); assert(strcmp(sha256Bytes(readBytes(file)),m.raw_sha256(i)))
    mask{i}=imread(file)==1; assert(strcmp(pixelHash(mask{i}),m.pixel_sha256(i)))
    assert(isequal(size(mask{i}),[m.h(i),m.w(i)]) && numel(extractRings(mask{i}))==m.rings(i))
end
A=nan(N,3,2);B=A;cover=A;statusRows=cell(0,8);logs=[0 0];nfixed=0;ntimed=0;
for part=["fixed","timed"]
    methods=["old_within","fast_within","old_cross","fast_cross"];
    if part=="timed",methods=[methods,"fast_geom","fast_geom_within"];end
    subset=true(N,1);if part=="fixed",subset=logical(m.fixed48);end
    for s=1:3
        for r=1:2
            path=fullfile(root,'perf_results',part,"S"+s,"rep"+r+".jsonl");
            f=fopen(path,'rt','n','UTF-8');assert(f>=0);guard=onCleanup(@()fclose(f));
            seen=false(N,numel(methods));vals=cell(N,2);line=fgetl(f);
            while ischar(line)
                t=jsondecode(line);line=fgetl(f);
                i=find(m.id==string(t.id));j=find(methods==string(t.method));
                assert(isscalar(i)&&isscalar(j)&&subset(i)&&~seen(i,j)&&t.session==s&&t.rep==r&&t.budget==256)
                assert(strcmp(t.stage,part)&&strcmp(t.dataset,'Oxford'));seen(i,j)=true;
                if part=="fixed",chosen=["old_cross","fast_cross"];else,chosen=["fast_within","fast_cross"];end
                side=find(chosen==string(t.method));if isempty(side),continue;end
                z=t.result;assert(t.nonempty==any(mask{i},'all') && z.rings==m.rings(i))
                v=struct('terminal',string(z.status),'available',false,'elapsed',z.return_ms,'length',0,'xor',NaN,'trace',"",'rounds',[]);
                ev=t.events;k=0;
                if ~isempty(ev)
                    clock=[ev.received_ms];assert(issorted(clock)&&all(clock>=[ev.serialized_ms])&&clock(end)<=z.return_ms)
                    assert(isequal([ev.round],0:numel(ev)-1))
                    if part=="fixed",take=1:numel(ev);k=numel(ev);
                    else,k=find(clock<=100,1,'last');take=k;end
                    hashes=strings(numel(take),1);
                    for h=1:numel(take)
                        e=ev(take(h));digest=string(e.sha256);fileKey=char(m.id(i)+"/"+digest);
                        if ~isKey(binary,fileKey)
                            bytes=readBytes(fullfile(root,'local','perf','blobs',digest+".pm3"));
                            assert(strcmp(sha256Bytes(bytes),digest));decoded=decodePM31(bytes);assert(isequal(size(decoded),size(mask{i})))
                            binary(fileKey)=[numel(bytes),nnz(xor(decoded,mask{i}))];
                        end
                        q=binary(fileKey);assert(isequal(q,[e.nbytes,e.xor]) && q(1)<=256)
                        hashes(h)=digest;v.length=q(1);v.xor=q(2);
                    end
                    v.trace=join(hashes,"/");
                end
                v.available=~isempty(k)&&k>0;
                if part=="fixed",v.rounds=z.rounds;assert(v.available==strcmp(z.status,'success'));end
                vals{i,side}=v;
            end
            clear guard
            assert(all(seen(subset,:),'all') && ~any(seen(~subset,:),'all'))
            if part=="fixed",logs(1)=logs(1)+nnz(seen);else,logs(2)=logs(2)+nnz(seen);end
            for i=find(subset)'
                x=vals{i,1};y=vals{i,2};reason="eligible";
                if part=="fixed"
                    assert(x.terminal==y.terminal && isequal(x.trace,y.trace) && isequaln(x.rounds,y.rounds))
                    if ~x.available || ~y.available,reason="no_common_file";
                    elseif ~any(mask{i},'all'),reason="empty_mask";
                    elseif any(~isfinite([x.elapsed,y.elapsed])) || min(x.elapsed,y.elapsed)<.0001,reason="invalid_or_subtick";
                    else,A(i,s,r)=log(y.elapsed/x.elapsed);nfixed=nfixed+1;end
                else
                    cover(i,s,r)=double(y.available)-double(x.available);
                    if m.rings(i)<2,reason="outside_multiring_scope";
                    elseif ~x.available||~y.available,reason="not_both_timely";
                    elseif x.length~=y.length,reason="different_lengths";
                    else,B(i,s,r)=x.xor-y.xor;ntimed=ntimed+1;end
                end
                statusRows(end+1,:)={part,m.id(i),s,r,x.terminal,y.terminal, ...
                    double(x.available)+2*double(y.available),reason};
            end
        end
    end
end
assert(isequal(logs,[1152 7200]) && all(isfinite(cover),'all'))
writetable(cell2table(statusRows,'VariableNames',{'grid','id','session','rep','first_terminal','second_terminal','availability_bits','eligibility'}),fullfile(out,'pair_disposition.csv'))
%三维数组按源、会话、重复排列，先均重复，再均会话
av=reduce(A);bv=reduce(B);cv=reduce(cover);
writetable(table(m.id,logical(m.fixed48),m.rings,av,bv,cv,'VariableNames', ...
    {'id','fixed48','rings','fixed_log_ratio','quality_gain','coverage_difference'}),fullfile(out,'source_recalculation.csv'))
av=av(isfinite(av));bv=bv(isfinite(bv));ciA=exp(resampleSources(av));ciB=resampleSources(bv);ciC=resampleSources(cv);
sessions=reshape(mean(mean(B,3,'omitnan'),1,'omitnan'),1,3);
loo=(sum(bv)-bv)/(numel(bv)-1);
result=struct('grid_calls',logs,'verified_source_blobs',binary.Count,'fixed_scheduled_sources',48, ...
    'fixed_sources',numel(av),'fixed_pairs',nfixed,'fixed_cross_ratio',exp(mean(av)), ...
    'A_ci95',ciA(1:2),'A_ci975',ciA(3:4),'A_supported',ciA(4)<1, ...
    'quality_sources',numel(bv),'quality_pairs',ntimed,'mean_xor_gain',mean(bv), ...
    'B_ci95',ciB(1:2),'B_ci975',ciB(3:4),'coverage_difference',mean(cv),'coverage_ci95',ciC(1:2), ...
    'session_gain',sessions,'all_three_sessions_positive',all(sessions>0),'all_leave_one_out_positive',all(loo>0), ...
    'B_supported',numel(bv)>1 && ciB(3)>0 && all(sessions>0) && all(loo>0) && ciC(1)>=-.02);
end

function v=reduce(x)
v=mean(mean(x,3,'omitnan'),2,'omitnan');
end

function bounds=resampleSources(v)
%按相同源序整源重抽，逐批保存均值，并对经验分位点手工线性插值
saved=rng;guard=onCleanup(@()rng(saved));rng(40121,'twister');
n=numel(v);draws=zeros(10000,1);
for i=1:100:10000
    chosen=randi(n,n,100);draws(i:i+99)=mean(reshape(v(chosen),n,100),1)';
end
draws=sort(draws);at=0.5+numel(draws)*[.025,.975,.0125,.9875];
lo=floor(at);frac=at-lo;bounds=reshape((1-frac(:)).*draws(lo(:))+frac(:).*draws(lo(:)+1),1,4);
end

function perfAnalysis(root,mode)
%正式统计及图仅从新会话、真实文件和新名单构建，开发未过门时只生成开发材料
if nargin<2,mode="formal";end
addpath(genpath(fullfile(root,'src')),genpath(fullfile(root,'performance')));
if strcmpi(mode,'test')||strcmpi(mode,'testFigures'),validateHelpers(root);schemaExercise(root,strcmpi(mode,'testFigures'));return;end
dirOut=fullfile(root,'perf_results','output');if ~isfolder(dirOut),mkdir(dirOut);end
if strcmpi(mode,'no-go')||strcmpi(mode,'development')
    perfFigures(root,'development');return
end
assert(strcmpi(mode,'formal'));manifest=readtable(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv'),'TextType','string');
assert(height(manifest)==200 && nnz(manifest.fixed48)==48 && numel(unique(manifest.id))==200);
[fixed,fEvents]=grid(root,"fixed",manifest(logical(manifest.fixed48),:),["old_within","fast_within","old_cross","fast_cross"]);
[timed,tEvents]=grid(root,"timed",manifest,["old_within","fast_within","old_cross","fast_cross","fast_geom","fast_geom_within"]);
fixedTiming(fixed,fEvents,manifest,dirOut);
memorySummary(fixed,dirOut);
obs=observations(root,timed,tEvents,manifest);writetable(obs,fullfile(dirOut,'timed_observations.csv'));
timedQuality(obs,manifest,dirOut);
fourWay(obs,dirOut);
compareReceipts(tEvents,dirOut,"timed");
decisions(root,dirOut,obs);
perfFigures(root,'formal');
end

function [c,e]=grid(root,part,manifest,methods)
folder=fullfile(root,'perf_results',part);c=readtable(fullfile(folder,'calls.csv'),'TextType','string');e=readtable(fullfile(folder,'events.csv'),'TextType','string');
key={'dataset','id','session','rep','budget','method'};
assert(all(c.dataset=="Oxford")&&all(c.budget==256)&&all(ismember(c.id,manifest.id))&&all(ismember(c.method,methods)));
assert(height(c)==height(manifest)*numel(methods)*6 && height(unique(c(:,key)))==height(c));
assert(isequal(unique(c.session),[1;2;3]) && isequal(unique(c.rep),[1;2]) && height(unique(e(:,[key,{'round'}])))==height(e));
[match,idx]=ismember(e(:,key),c(:,key));assert(all(match) && all(e.received_ms<=c.return_ms(idx)) && all(e.serialized_ms<=e.received_ms) && all(e.nbytes<=e.budget));
[~,loc]=ismember(c.id,manifest.id);native=c.rings;verifiable=isfinite(native);assert(all(native(verifiable)==manifest.rings(loc(verifiable))));c.measured_rings=native;c.rings=manifest.rings(loc);c.stratum=manifest.stratum(loc);
[~,loc]=ismember(e.id,manifest.id);e.rings=manifest.rings(loc);e.stratum=manifest.stratum(loc);
end

function fixedTiming(c,e,manifest,out)
keys={'dataset','id','session','rep','budget'};
vars={'status','n_events','nonempty','return_ms','first_ms','final_sha','trace_sha','rings','stratum'};
allPairs={};sources={};summary={};sessionRows={};
for method=["cross","within"]
    p=joinMethods(c,"old_"+method,"fast_"+method,keys,vars);p.method=repmat(method,height(p),1);
    p.eligibility=repmat("paired",height(p),1);
    p.eligibility(p.old_status~="success"|p.fast_status~="success")="no_common_legal_file";
    p.eligibility(p.eligibility=="paired" & (~logical(p.old_nonempty)|~logical(p.fast_nonempty)))="empty_source";
    good=p.eligibility=="paired";
    assert(all(p.old_final_sha(good)==p.fast_final_sha(good) & p.old_trace_sha(good)==p.fast_trace_sha(good) & p.old_n_events(good)==p.fast_n_events(good)),'PERF:WorkMismatch','Fixed calls have divergent work or bytes');
    for metric=["return_ms","first_ms"]
        t=p;v=t.("old_"+metric);w=t.("fast_"+metric);t.metric=repmat(metric,height(t),1);
        t.eligibility(good & (~isfinite(v)|~isfinite(w)|v<=0|w<=0))="invalid_or_zero_duration";
        %计时器实测每秒一千万个刻度，小于一个刻度的正读数单独登记
        subTick=good & isfinite(v) & isfinite(w) & v>0 & w>0 & (v<0.0001 | w<0.0001);
        t.eligibility(subTick)="below_clock_resolution";eligible=t.eligibility=="paired";
        t.log_ratio=nan(height(t),1);t.log_ratio(eligible)=log(w(eligible)./v(eligible));allPairs{end+1}=t;
        for scope=["all","R1","R2+","near","holes","components","simple"]
            take=eligible;
            if scope=="R1",take=take & t.old_rings==1;elseif scope=="R2+",take=take & t.old_rings>=2;elseif scope~="all",take=take & t.old_stratum==scope;end
            z=t(take,:);v=meanSource(z,'log_ratio');
            if ~isempty(v),v.ratio=exp(v.mean_value);v.method=repmat(method,height(v),1);v.scope=repmat(scope,height(v),1);v.metric=repmat(metric,height(v),1);sources{end+1}=v;end
            vals=v.mean_value;ci=exp(perfCI(vals));summary(end+1,:)={method,metric,scope,numel(vals),height(z),exp(mean(vals)),ci(1),ci(2),ci(3),ci(4)};
            for sid=reshape(unique(c.session),1,[])
                zz=z(z.session==sid,:);vv=meanSource(zz,'log_ratio');sc=exp(perfCI(vv.mean_value));
                sessionRows(end+1,:)={method,metric,scope,sid,height(vv),height(zz),exp(mean(vv.mean_value)),sc(1),sc(2),sc(3),sc(4)};
            end
        end
    end
end
names={'method','metric','scope','n_sources','n_pairs','ratio','ci95_low','ci95_high','ci975_low','ci975_high'};
writetable(vertcat(allPairs{:}),fullfile(out,'fixed_pairs.csv'));if ~isempty(sources),writetable(vertcat(sources{:}),fullfile(out,'fixed_by_source.csv'));end
writetable(cell2table(summary,'VariableNames',names),fullfile(out,'fixed_summary.csv'));
writetable(cell2table(sessionRows,'VariableNames',[names(1:3),{'session'},names(4:end)]),fullfile(out,'fixed_sessions.csv'));
compareReceipts(e,out,"fixed");
assert(all(ismember(c.id,manifest.id(logical(manifest.fixed48)))));
end

function v=meanSource(z,field)
if isempty(z),v=table(strings(0,1),zeros(0,1),zeros(0,1),'VariableNames',{'id','mean_value','n_pairs'});return;end
[g,id,~]=findgroups(z.id,z.session);m=splitapply(@mean,z.(field),g);nn=splitapply(@numel,z.(field),g);[g,id]=findgroups(id);
v=table(id,splitapply(@mean,m,g),splitapply(@sum,nn,g),'VariableNames',{'id','mean_value','n_pairs'});
end

function p=joinMethods(c,old,fast,keys,fields)
a=c(c.method==old,[keys,fields]);b=c(c.method==fast,[keys,fields]);
a=renamevars(a,fields,"old_"+string(fields));b=renamevars(b,fields,"fast_"+string(fields));
p=innerjoin(a,b,'Keys',keys);
end

function compareReceipts(ev,out,tag)
%验证同一轮的字节身份，保存实收差与相邻检查点的间隔
key={'dataset','id','session','rep','budget','round'};sortKey={'dataset','id','method','session','rep','budget','round'};
ev=sortrows(ev,sortKey);ev.interval_ms=ev.received_ms;
if height(ev)>1
    equal=ev.id(2:end)==ev.id(1:end-1) & ev.method(2:end)==ev.method(1:end-1) & ev.session(2:end)==ev.session(1:end-1) & ev.rep(2:end)==ev.rep(1:end-1) & ev.budget(2:end)==ev.budget(1:end-1);
    ii=find(equal)+1;ev.interval_ms(ii)=ev.received_ms(ii)-ev.received_ms(ii-1);assert(all(ev.interval_ms>=0));
end
fields={'sha256','received_ms','interval_ms','xor','nbytes','rings','stratum'};pairedTables={};
for method=["cross","within"]
    p=joinMethods(ev,"old_"+method,"fast_"+method,key,fields);p.method=repmat(method,height(p),1);
    p.same_file=p.old_sha256==p.fast_sha256;p.receipt_delta_ms=p.fast_received_ms-p.old_received_ms;
    assert(all(p.same_file),'PERF:CommonRoundMismatch','Difference on a common deterministic checkpoint');
    pairedTables{end+1}=p;
end
data=vertcat(pairedTables{:});summaries=cell(0,12);
for metric=["received_ms","interval_ms"]
    a=data.("old_"+metric);b=data.("fast_"+metric);
    status=repmat("paired",height(data),1);status(~isfinite(a)|~isfinite(b)|a<=0|b<=0)="invalid_or_zero_duration";
    status(isfinite(a)&isfinite(b)&a>0&b>0&(a<0.0001|b<0.0001))="below_clock_resolution";
    val=nan(height(data),1);eligible=status=="paired";val(eligible)=log(b(eligible)./a(eligible));
    data.(metric+"_eligibility")=status;data.(metric+"_log_ratio")=val;
    for method=["within","cross"]
        for round=reshape(unique(data.round),1,[])
            for scope=["all","R2+"]
                offered=data.method==method & data.round==round;if scope=="R2+",offered=offered & data.old_rings>=2;end
                z=data(offered & eligible,:);v=meanSource(z,metric+"_log_ratio");ci=exp(perfCI(v.mean_value));
                summaries(end+1,:)={method,metric,round,scope,nnz(offered),height(z),height(v),exp(mean(v.mean_value)),ci(1),ci(2),ci(3),ci(4)};
            end
        end
    end
end
writetable(data,fullfile(out,tag+"_common_receipts.csv"));
names={'method','metric','round','scope','offered','n_pairs','n_sources','ratio','ci95_low','ci95_high','ci975_low','ci975_high'};
writetable(cell2table(summaries,'VariableNames',names),fullfile(out,tag+"_checkpoint_ratios.csv"));
end

function obs=observations(root,c,e,manifest)
keys={'dataset','id','session','rep','budget','method'};[tf,callId]=ismember(e(:,keys),c(:,keys));assert(all(tf));
obs=c(repelem((1:height(c)).',2),:);obs.deadline=repmat([100;200],height(c),1);obs.final_status=obs.status;
obs.nbytes=nan(height(obs),1);obs.xor=obs.nbytes;obs.round=obs.nbytes;obs.received_ms=obs.nbytes;obs.fp=obs.nbytes;obs.fn=obs.nbytes;obs.iou=obs.nbytes;obs.rmse=obs.nbytes;
obs.sha256=strings(height(obs),1);masks=containers.Map('KeyType','char','ValueType','any');cache=containers.Map('KeyType','char','ValueType','any');
for d=[100 200]
    selected=find(e.received_ms<=d);[~,last]=unique(callId(selected),'last');indices=selected(last);oi=2*callId(indices)-double(d==100);
    active=obs.deadline==d & (obs.return_ms>d|obs.status=="success");obs.status(active)="not_ready";
    obs.status(oi)="success";obs.nbytes(oi)=e.nbytes(indices);obs.xor(oi)=e.xor(indices);obs.round(oi)=e.round(indices);obs.received_ms(oi)=e.received_ms(indices);obs.sha256(oi)=e.sha256(indices);
    for j=reshape(oi,1,[])
        id=char(obs.id(j));digest=char(obs.sha256(j));cacheKey=[id '/' digest];
        if ~isKey(cache,cacheKey)
            if ~isKey(masks,id),masks(id)=readFrozenMask(root,manifest(manifest.id==string(id),:));end
            bytes=readBytes(fullfile(root,'local','perf','blobs',[digest '.pm3']));assert(numel(bytes)==obs.nbytes(j)&&strcmp(sha256Bytes(bytes),digest));
            raw=masks(id);decoded=decodePM31(bytes);m=pixelScores(raw,decoded);assert(m.xor==obs.xor(j));
            cache(cacheKey)=[m.fp,m.fn,m.iou,m.rmse];
        end
        v=cache(cacheKey);assert(v(1)+v(2)==obs.xor(j));obs.fp(j)=v(1);obs.fn(j)=v(2);obs.iou(j)=v(3);obs.rmse(j)=v(4);
    end
end
assert(height(obs)==2*height(c) && all(isnan(obs.xor(obs.status~="success"))));
end

function timedQuality(obs,manifest,out)
%同一输入、进程、重复与截止时刻配对，先平均重复，再平均有效会话，最后源等权
comparisons=["fast_cross","fast_within";"fast_cross","fast_geom";"fast_cross","fast_geom_within";"fast_cross","old_cross";"fast_within","old_within";"old_cross","old_within"];
key={'dataset','id','session','rep','budget','deadline'};
fields={'status','nbytes','round','xor','fp','fn','iou','rmse','received_ms','sha256','first_ms','return_ms','rings','stratum'};
sources={};pairs={};summ={};ss={};loos={};covers={};
for i=1:size(comparisons,1)
    method=comparisons(i,1);base=comparisons(i,2);p=joinMethods(obs,base,method,key,fields);
    p.method=repmat(method,height(p),1);p.baseline=repmat(base,height(p),1);a=p.fast_status=="success";b=p.old_status=="success";
    p.common=a & b & p.fast_nbytes==p.old_nbytes;p.availability=repmat("neither",height(p),1);
    p.availability(a & ~b)="method_only";p.availability(b & ~a)="baseline_only";p.availability(a&b)="both";
    p.availability(a&b & ~p.common)="both_different_length";p.cover_delta=double(a)-double(b);
    p.gain=p.old_xor-p.fast_xor;p.relative_gain=p.gain./max(1,p.old_xor);p.iou_gain=p.fast_iou-p.old_iou;p.fp_gain=p.old_fp-p.fast_fp;p.fn_gain=p.old_fn-p.fast_fn;p.rmse_gain=p.old_rmse-p.fast_rmse;
    p.gain(~p.common)=NaN;p.relative_gain(~p.common)=NaN;p.iou_gain(~p.common)=NaN;p.fp_gain(~p.common)=NaN;p.fn_gain(~p.common)=NaN;p.rmse_gain(~p.common)=NaN;pairs{end+1}=p;
    for deadline=[100 200]
        for scope=["all","R2+","R1","near","holes","components","simple"]
            subset=p.deadline==deadline;
            if scope=="R2+",subset=subset&p.old_rings>=2;elseif scope=="R1",subset=subset&p.old_rings==1;elseif scope~="all",subset=subset&p.old_stratum==scope;end
            z=p(subset,:);both=z(z.common,:);v=meanSource(both,'gain');x=v.mean_value;ci=perfCI(x);
            cov=meanSource(z,'cover_delta');cc=perfCI(cov.mean_value);
            covers(end+1,:)={method,base,deadline,scope,height(z),height(cov),nnz(z.fast_status=="success"),nnz(z.old_status=="success"),nnz(z.fast_status=="success" & z.old_status=="success"),nnz(z.availability=="method_only"),nnz(z.availability=="baseline_only"),nnz(z.availability=="neither"),nnz(z.availability=="both_different_length"),mean(cov.mean_value),cc(1),cc(2)};
            full=x(v.n_pairs==6);cf=perfCI(full);
            summ(end+1,:)={method,base,deadline,scope,height(z),numel(x),height(both),mean(x),median(x),ci(1),ci(2),ci(3),ci(4),nnz(x>0),nnz(x==0),nnz(x<0),numel(full),mean(full),cf(1),cf(2),cf(3),cf(4)};
            n=numel(x);loso=nan(n,1);if n>=2,loso=(sum(x)-x)/(n-1);end
            if n>0
                v.xor_gain=v.mean_value;v.method=repmat(method,n,1);v.baseline=repmat(base,n,1);v.deadline=repmat(deadline,n,1);v.scope=repmat(scope,n,1);
                for var=["relative_gain","iou_gain","fp_gain","fn_gain","rmse_gain"]
                    aux=meanSource(both,char(var));assert(isequal(v.id,aux.id));v.(var)=aux.mean_value;
                end
                sources{end+1}=v;
                leave=v(:,{'method','baseline','deadline','scope','id'});leave.leave_one_mean=loso;loos{end+1}=leave;
            end
            for sid=reshape(unique(obs.session),1,[])
                t=meanSource(both(both.session==sid,:),'gain');sc=perfCI(t.mean_value);
                ss(end+1,:)={method,base,deadline,scope,sid,height(t),sum(t.n_pairs),mean(t.mean_value),sc(1),sc(2),sc(3),sc(4)};
            end
        end
    end
end
prefix={'method','baseline','deadline','scope'};
writetable(vertcat(pairs{:}),fullfile(out,'timed_pairs.csv'));
if isempty(sources)
    sTable=table('Size',[0 13],'VariableTypes',{'string','double','double','double','string','string','double','string','double','double','double','double','double'},...
        'VariableNames',{'id','mean_value','n_pairs','xor_gain','method','baseline','deadline','scope','relative_gain','iou_gain','fp_gain','fn_gain','rmse_gain'});
    lTable=sTable(:,{'method','baseline','deadline','scope','id'});lTable.leave_one_mean=zeros(0,1);
else
    sTable=vertcat(sources{:});lTable=vertcat(loos{:});
end
writetable(sTable,fullfile(out,'timed_by_source.csv'));writetable(lTable,fullfile(out,'timed_leave_one_out.csv'));
writetable(cell2table(summ,'VariableNames',[prefix,{'offered','n_sources','n_pairs','mean_gain','median_gain','ci95_low','ci95_high','ci975_low','ci975_high','wins','ties','losses','six_success_sources','six_mean','six_ci95_low','six_ci95_high','six_ci975_low','six_ci975_high'}]),fullfile(out,'timed_quality.csv'));
writetable(cell2table(covers,'VariableNames',[prefix,{'calls','sources','timely_method','timely_baseline','both','method_only','baseline_only','neither','both_different_length','cover_delta','ci95_low','ci95_high'}]),fullfile(out,'timed_coverage.csv'));
writetable(cell2table(ss,'VariableNames',[prefix,{'session','n_sources','n_pairs','mean_gain','ci95_low','ci95_high','ci975_low','ci975_high'}]),fullfile(out,'timed_sessions.csv'));
assert(all(ismember(obs.id,manifest.id)));
[group,flags]=findgroups(obs(:,{'method','deadline','status','final_status'}));flags.calls=splitapply(@numel,obs.rep,group);writetable(flags,fullfile(out,'timed_failures_and_success.csv'));
end

function decisions(root,out,obs)
rd=@(f)readtable(fullfile(out,f),'TextType','string');fixed=rd('fixed_summary.csv');panel=rd('timed_quality.csv');cov=rd('timed_coverage.csv');
sessions=rd('timed_sessions.csv');loo=rd('timed_leave_one_out.csv');
a=fixed(fixed.method=="cross" & fixed.metric=="return_ms" & fixed.scope=="all",:);
b=panel(panel.method=="fast_cross" & panel.baseline=="fast_within" & panel.deadline==100 & panel.scope=="R2+",:);
c=cov(cov.method=="fast_cross" & cov.baseline=="fast_within" & cov.deadline==100 & cov.scope=="all",:);
s=sessions(sessions.method=="fast_cross" & sessions.baseline=="fast_within" & sessions.deadline==100 & sessions.scope=="R2+",:);
l=loo(loo.method=="fast_cross" & loo.baseline=="fast_within" & loo.deadline==100 & loo.scope=="R2+",:);
A=a.n_sources>0 && a.ci975_high<1;B=b.n_sources>1 && b.ci975_low>0 && height(s)==3 && all(s.mean_gain>0) && height(l)==b.n_sources && all(l.leave_one_mean>0) && c.ci95_low>=-.02;
result=struct('A_supported',A,'fixed_cross_ratio',a.ratio,'A_ci95',[a.ci95_low a.ci95_high],'A_ci975',[a.ci975_low a.ci975_high], ...
    'B_supported',B,'quality_sources',b.n_sources,'quality_pairs',b.n_pairs,'mean_xor_gain',b.mean_gain,'B_ci95',[b.ci95_low b.ci95_high],'B_ci975',[b.ci975_low b.ci975_high], ...
    'coverage_difference',c.cover_delta,'coverage_ci95',[c.ci95_low c.ci95_high],'all_three_sessions_positive',height(s)==3 && all(s.mean_gain>0),'all_leave_one_out_positive',height(l)>0 && all(l.leave_one_mean>0));
writeJson(fullfile(out,'formal_claims.json'),result);
support=["未满足","满足"];
lines=["# 精确评价优化的独立确认";"";sprintf('固定工作量的 fast_cross/old_cross 时间比为 %.4f，95%% 区间 [%.4f, %.4f]，双侧97.5%%区间 [%.4f, %.4f]。计入 %d 个非空合格源、%d 次同工作量配对，%s性能主张A的判据。',a.ratio,a.ci95_low,a.ci95_high,a.ci975_low,a.ci975_high,a.n_sources,a.n_pairs,support(1+A)); ...
    "";sprintf('新Oxford多环、256 B、100 ms 下，快版圈内减快版跨圈的来源均差为 %.4f 像素，95%%区间 [%.4f, %.4f]，双侧97.5%%区间 [%.4f, %.4f]。%d 个共同源、%d 个同次同码长重复对；按源改善、持平、退化 %d/%d/%d，中位数 %.4f。',b.mean_gain,b.ci95_low,b.ci95_high,b.ci975_low,b.ci975_high,b.n_sources,b.n_pairs,b.wins,b.ties,b.losses,b.median_gain); ...
    sprintf('三个会话依序为 %s 像素。全六次共同成功 %d 源，其均差 %.4f。全部200源交付率差为 %.3f 个百分点，95%%区间 [%.3f, %.3f]。联合条件%s质量主张B的判据。',char(join(compose("%.4f",s.mean_gain),", ")),b.six_success_sources,b.six_mean,100*c.cover_delta,100*c.ci95_low,100*c.ci95_high,support(1+B))];
if height(l)>1,lines(end+1)=sprintf('逐一删源均差范围 [%.4f, %.4f] 像素。',min(l.leave_one_mean),max(l.leave_one_mean));end
for base=["fast_geom","fast_geom_within"]
    x=panel(panel.method=="fast_cross" & panel.baseline==base & panel.deadline==100 & panel.scope=="all",:);
    lines(end+1)=sprintf('对 %s 的全环数次要比较计入 %d 源、%d 对，正值表示完整方法少错，平均差 %.4f，95%%区间 [%.4f, %.4f]。',base,x.n_sources,x.n_pairs,x.mean_gain,x.ci95_low,x.ci95_high);
end
lines(end+1)="固定工作量的首份、逐轮实收及间隔见 fixed_checkpoint_ratios.csv。各方法的进程前后内存快照见 fixed_memory.csv。四格同次等码长子集见 four_way_summary.csv。";
bytes=unicode2native(char(join(lines(:),newline)+newline),'UTF-8');fid=fopen(fullfile(out,'formal_summary.md'),'wb');assert(fid>=0);assert(fwrite(fid,bytes,'uint8')==numel(bytes));assert(fclose(fid)==0);
%四格只作同源同会话的条件比较，另列全体计划调用的覆盖及完成轮次分布
selection=ismember(obs.method,["old_within","fast_within","old_cross","fast_cross"]);q=obs(selection,:);
[g,t]=findgroups(q(:,{'method','deadline'}));t.scheduled=splitapply(@numel,q.rep,g);t.timely=splitapply(@sum,double(q.status=="success"),g);
t.rate=t.timely./t.scheduled;t.median_received_round=splitapply(@(x)median(x,'omitnan'),q.round,g);t.median_final_return_ms=splitapply(@median,q.return_ms,g);
writetable(t,fullfile(out,'four_cells.csv'));
qd=q(q.status=="success",:);[g,t]=findgroups(qd(:,{'method','deadline','round'}));t.calls=splitapply(@numel,qd.rep,g);
writetable(t,fullfile(out,'received_rounds.csv'));
end

function fourWay(obs,out)
%四种实现/操作方式同时按时同码长才计算两种机制效应之差
keys={'dataset','id','session','rep','budget','deadline'};
methods=["old_within","old_cross","fast_within","fast_cross"];t=table();
for name=methods
    v=obs(obs.method==name,[keys,{'nbytes','status','xor','round','rings'}]);
    v=renamevars(v,{'nbytes','status','xor','round','rings'},name+["_length","_status","_xor","_round","_rings"]);
    if isempty(t),t=v;else,t=innerjoin(t,v,'Keys',keys);end
end
assert(height(t)==nnz(obs.method=="old_within") && height(unique(t(:,keys)))==height(t));ready=false(height(t),4);lengths=zeros(height(t),4);
for i=1:4,ready(:,i)=t.(methods(i)+"_status")=="success";lengths(:,i)=t.(methods(i)+"_length");end
t.presence_code=double(ready)*[1;2;4;8];t.all_equal_bytes=all(ready,2)&all(lengths==lengths(:,1),2);
t.old_mechanism=t.old_within_xor-t.old_cross_xor;t.fast_mechanism=t.fast_within_xor-t.fast_cross_xor;
t.fast_minus_old_mechanism=t.fast_mechanism-t.old_mechanism;t.old_mechanism(~t.all_equal_bytes)=NaN;t.fast_mechanism(~t.all_equal_bytes)=NaN;t.fast_minus_old_mechanism(~t.all_equal_bytes)=NaN;
writetable(t,fullfile(out,'four_way_pairs.csv'));rows=cell(0,11);
for d=[100 200]
    for scope=["all","R2+"]
        offered=t.deadline==d;if scope=="R2+",offered=offered&t.old_within_rings>=2;end
        z=t(offered&t.all_equal_bytes,:);
        for metric=["old_mechanism","fast_mechanism","fast_minus_old_mechanism"]
            v=meanSource(z,char(metric));ci=perfCI(v.mean_value);rows(end+1,:)={d,scope,metric,nnz(offered),height(v),height(z),mean(v.mean_value),ci(1),ci(2),ci(3),ci(4)};
        end
    end
end
writetable(cell2table(rows,'VariableNames',{'deadline','scope','metric','offered','n_sources','n_pairs','mean_gain','ci95_low','ci95_high','ci975_low','ci975_high'}),fullfile(out,'four_way_summary.csv'));
end

function validateHelpers(root)
%仅用合成的小数列和已授权开发图验证统计单位及输入分层
id=["a";"a";"a";"b"];session=[1;1;2;1];rep=[1;2;1;1];score=[1;3;8;4];
z=table(id,session,rep,score);v=meanSource(z,'score');assert(isequal(v.mean_value,[5;4])&&isequal(v.n_pairs,[3;1]));
assert(isequal(perfCI([2;2;2]),[2 2 2 2])&&all(isnan(perfCI([])))&&isequal(perfCI([1;3;5]),perfCI([1;3;5])));
hist=readtable(fullfile(root,'performance','sampling','oxford_historical_screen.csv'),'TextType','string');
dev=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');assert(all(dev.official=="trainval"));
for k=1:height(dev)
    r=dev(k,:);raw=readFrozenMask(root,r);s=perfStratum(raw);assert(s==hist.stratum(hist.id==r.id),'PERF:DevStrata','Incorrect historical descriptor on %s',r.id);
end
end

function schemaExercise(root,includeFigures)
%用临时的合成时钟夹具检验截止筛选；这里给定的时间只作单元测试
scratch=tempname;mkdir(scratch);guard=onCleanup(@()cleanScratch(scratch));
folder=fullfile(scratch,'local','perf','blobs');mkdir(folder);mkdir(fullfile(scratch,'perf_results','output'));
raw=false(12,18);raw(2:5,2:5)=true;raw(7:11,10:15)=true;
[r,par]=extractRings(raw);bytes=packPM31(size(raw),r,par);sha=string(sha256Bytes(bytes));p=fullfile(folder,sha+".pm3");
fid=fopen(p,'wb');fwrite(fid,bytes,'uint8');fclose(fid);
id=["fixtureA";"fixtureB"];file=id+".png";for j=1:2,imwrite(uint8(raw),fullfile(scratch,file(j)));end
rawHash=string(sha256Bytes(readBytes(fullfile(scratch,file(1)))));ph=string(pixelHash(raw));
m=table(repmat("Oxford",2,1),id,file,repmat(rawHash,2,1),repmat(ph,2,1),[18;18],[12;12],[2;2],repmat("components",2,1),true(2,1), ...
    'VariableNames',{'dataset','id','file','raw_sha256','pixel_sha256','w','h','rings','stratum','fixed48'});
cols={'dataset','id','session','rep','budget','method','status','rings','stratum','nonempty','return_ms','first_ms','n_events','final_sha','trace_sha'};
clockRows=cell(0,numel(cols));eventRows=cell(0,13);
for j=1:2
    for sid=1:3
        for rep=1:2
            for method=["old_within","old_cross","fast_within","fast_cross","fast_geom","fast_geom_within"]
                t=100;if method=="old_within" && j==1 && sid==1 && rep==2,t=100.1;end
                total=180;if startsWith(method,"fast"),total=144;end
                info={"Oxford",id(j),sid,rep,256,method};
                clockRows(end+1,:)=[info,{"success",2,"components",true,total,t,1,sha,"toy-common-trace"}];
                eventRows(end+1,:)=[info,{0,0,numel(bytes),sha,t,t-.1,2}];
            end
        end
    end
end
c=cell2table(clockRows,'VariableNames',cols);e=cell2table(eventRows,'VariableNames',{'dataset','id','session','rep','budget','method','round','xor','nbytes','sha256','received_ms','serialized_ms','rings'});
e.stratum=repmat("components",height(e),1);o=observations(scratch,c,e,m);
assert(nnz(o.status=="not_ready")==1 && nnz(o.status=="success")==height(o)-1 && all(o.xor(o.status=="success")==0));
out=fullfile(scratch,'perf_results','output');timedQuality(o,m,out);fourWay(o,out);
fc=c(ismember(c.method,["old_within","old_cross","fast_within","fast_cross"]),:);
below=fc.method=="old_cross" & fc.id=="fixtureB" & fc.session==1 & fc.rep==1;fc.first_ms(below)=0.00005;
fixedTiming(fc,e,m,out);
guardRows=readtable(fullfile(out,'fixed_pairs.csv'),'TextType','string');
assert(nnz(guardRows.eligibility=="below_clock_resolution" & guardRows.method=="cross" & guardRows.metric=="first_ms")==1);
t=readtable(fullfile(out,'timed_quality.csv'),'TextType','string');z=t(t.method=="old_cross" & t.baseline=="old_within" & t.deadline==100 & t.scope=="R2+",:);
assert(height(z)==1 && z.n_pairs==11 && z.n_sources==2 && z.six_success_sources==1 && z.mean_gain==0);
ww=readtable(fullfile(out,'four_way_summary.csv'),'TextType','string');z=ww(ww.scope=="R2+" & ww.deadline==100 & ww.metric=="fast_minus_old_mechanism",:);assert(z.n_pairs==11 && z.mean_gain==0);
ff=readtable(fullfile(out,'fixed_summary.csv'),'TextType','string');z=ff(ff.method=="cross" & ff.metric=="return_ms" & ff.scope=="all",:);assert(abs(z.ratio-.8)<1e-12);
decisions(scratch,out,o);d=jsondecode(fileread(fullfile(out,'formal_claims.json')));assert(d.A_supported && ~d.B_supported);
if includeFigures
    %这两张合成蒙版只写入临时夹具目录，程序退出后清理；不打开任何新测试样本
    md=fullfile(scratch,'data','manifests','exact_fast');mkdir(md);writetable(m,fullfile(md,'exact_fast_confirm.csv'));writetable(o,fullfile(out,'timed_observations.csv'));
    phase="dev1";if isfile(fullfile(root,'perf_results','dev2','decision.json')),phase="dev2";end
    part=fullfile(scratch,'perf_results',phase);mkdir(part);
    for file=["decision.json","gate.csv"],copyfile(fullfile(root,'perf_results',phase,file),fullfile(part,file));end
    for implementation=["reference",phase]
        target=fullfile(scratch,'perf_results','profiling',implementation);mkdir(target);
        source=fullfile(root,'perf_results','profiling',implementation,'functions.csv');
        if ~isfile(source)
            sealed=jsondecode(fileread(fullfile(root,'performance','selected_kernel.json')));assert(string(sealed.version)==implementation);
            source=fullfile(root,'perf_results','profiling','selected','functions.csv');
        end
        copyfile(source,fullfile(target,'functions.csv'));
    end
    perfFigures(scratch,'formal');
    audit=readtable(fullfile(out,'figures','figure_verification.csv'));assert(height(audit)==5 && all(audit.dpi_x>=300 & audit.dpi_y>=300));
end
end

function cleanScratch(path)
resolved=char(java.io.File(path).getCanonicalPath());base=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(lower(resolved),lower([base filesep])) && ~strcmpi(base,resolved));rmdir(resolved,'s');
end

function memorySummary(c,out)
%进程调用前后分别读取一次内存，最大快照也不能解释为调用期峰值
rows=cell(0,13);c.memory_delta=c.memory_after-c.memory_before;
for method=reshape(unique(c.method),1,[])
    m=c(c.method==method,:);
    for sid=[0 reshape(unique(c.session),1,[])]
        t=m;if sid>0,t=m(m.session==sid,:);end
        valid=isfinite(t.memory_before)&isfinite(t.memory_after)&t.memory_before>=0&t.memory_after>=0;
        a=t.memory_before(valid)/2^20;b=t.memory_after(valid)/2^20;d=b-a;
        if isempty(a)
            stats=nan(1,8);
        else
            stats=[median(a),prctile(a,95),median(b),prctile(b,95),max([a;b]),median(d),prctile(d,95),max(d)];
        end
        rows(end+1,:)=[{method,sid,height(t),nnz(valid),nnz(~valid)},num2cell(stats)];
    end
end
fields={'method','session_zero_means_all','calls','valid_snapshots','missing_snapshots','before_median_mib','before_p95_mib','after_median_mib','after_p95_mib','maximum_observed_snapshot_mib','delta_median_mib','delta_p95_mib','maximum_observed_delta_mib'};
writetable(cell2table(rows,'VariableNames',fields),fullfile(out,'fixed_memory.csv'));
end

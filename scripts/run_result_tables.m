function run_result_tables(root)
%各表直接引用本次MATLAB逐次记录和统计，不从历史文件读取预测值
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
folder=fullfile(root,'results');out=fullfile(folder,'tables');if ~isfolder(out),mkdir(out);end
a=readtable(fullfile(folder,'timing_probe_default_environment.csv'),'TextType','string');
b=readtable(fullfile(folder,'timing_probe_single_environment.csv'),'TextType','string');
env=[a;b];
%物理机资料来自本轮运行时保存的环境快照，重画表格时不读取绘图机的硬件
record=string(fileread(fullfile(root,'docs','environment.md')));
os=regexp(record,'Windows NT [0-9.]+，\s*PCWIN64','match','once');
cpu=regexp(record,'PCWIN64，([^。]+)','tokens','once');
memoryGB=regexp(record,'约\s*([0-9.]+)×10\^9 B','tokens','once');
toolbox=regexp(record,'Image Processing Toolbox\s*([0-9]+\.[0-9]+)','tokens','once');
assert(~isempty(os)&&~isempty(cpu)&&~isempty(memoryGB)&&~isempty(toolbox),'DIP:EnvironmentRecord','Incomplete frozen environment snapshot');
env.operating_system=repmat(string(os),height(env),1);env.cpu=repmat(string(cpu{1}),height(env),1);
memB=str2double(memoryGB{1})*1e9;exact=regexp(record,'物理内存\s*([0-9,]+) B','tokens','once');
if ~isempty(exact),memB=str2double(erase(string(exact{1}),','));end
env.memory_bytes=repmat(memB,height(env),1);env.image_processing_toolbox=repmat(string(toolbox{1}),height(env),1);
env.timing_start=repmat("in-memory binary mask",height(env),1);env.timing_endpoint=repmat("first instruction in synchronous receiver",height(env),1);
writetable(env,fullfile(out,'t01-environment.csv'));
methods=["seed";"matlab_geom";"matlab_geom_within";"within_full";"cross";"exact"];
start=["逐圈层级与有限候选分配";"原生几何简化";"原生几何简化";"逐圈层级与有限候选分配";"逐圈层级与有限候选分配";"逐圈层级与有限候选分配"];
move=["仅初始解";"仅初始解";"完整同圈删插";"完整同圈删插";"完整同圈及跨圈删插";"完整同圈及跨圈删插"];
order=["无";"无";"有限前24、可加下降、整图验收";"有限前24、可加下降、整图验收";"有限前24、可加下降、整图验收";"同一前24直接按整图错分排序"];
role=["初始对照";"传统几何基线";"传统几何加强基线";"主要机制对照";"完整方法";"登记子集补充"];
writetable(table(methods,start,move,order,role),fullfile(out,'t02-methods.csv'));
if ~isfile(fullfile(folder,'summary.csv')),return;end
read=@(f)readtable(fullfile(folder,f),'TextType','string');
summary=read('summary.csv');source=read('source_pairs.csv');obs=read('observations.csv');
assert(height(obs)==24336,'DIP:IncompleteGrid','Report tables require the complete observation grid');
geom=summary(summary.budget==256 & summary.deadline==100 & summary.method=="cross" & summary.scope=="all" & ...
    ismember(summary.baseline,["matlab_geom","matlab_geom_within"]),:);
geom.relative_saved_pct=NaN(height(geom),1);
for k=1:height(geom)
    sel=source.budget==256 & source.deadline==100 & source.dataset==geom.dataset(k) & source.method=="cross" & source.baseline==geom.baseline(k);
    geom.relative_saved_pct(k)=100*mean(source.relative_gain(sel));
end
writetable(geom,fullfile(out,'t03-geometry.csv'));
primary=summary(summary.budget==256 & summary.deadline==100 & summary.method=="cross" & summary.scope=="R2+" & summary.baseline=="within_full",:);
primary.within_mean_xor=NaN(height(primary),1);primary.cross_mean_xor=primary.within_mean_xor;
primary.relative_saved_pct=primary.within_mean_xor;primary.iou_gain_pp=primary.within_mean_xor;
for k=1:height(primary)
    sel=source.dataset==primary.dataset(k) & source.budget==256 & source.deadline==100 & source.method=="cross" & source.baseline=="within_full" & source.rings>=2;
    primary.relative_saved_pct(k)=100*mean(source.relative_gain(sel));primary.iou_gain_pp(k)=100*mean(source.iou_gain(sel));
    group=obs(obs.dataset==primary.dataset(k) & obs.budget==256 & obs.deadline==100 & obs.rings>=2 & obs.status=="success",:);
    keys={'id','session','rep'};fields=[keys {'nbytes','xor'}];
    ca=renamevars(group(group.method=="cross",fields),{'nbytes','xor'},{'ca_bytes','ca_d'});
    cb=renamevars(group(group.method=="within_full",fields),{'nbytes','xor'},{'cb_bytes','cb_d'});
    pair=innerjoin(ca,cb,'Keys',keys);pair=pair(pair.ca_bytes==pair.cb_bytes,:);
    if isempty(pair),continue;end
    [g,id,~]=findgroups(pair.id,pair.session);ca=splitapply(@mean,pair.ca_d,g);cb=splitapply(@mean,pair.cb_d,g);
    [g,~]=findgroups(id);primary.cross_mean_xor(k)=mean(splitapply(@mean,ca,g));primary.within_mean_xor(k)=mean(splitapply(@mean,cb,g));
    assert(abs(primary.within_mean_xor(k)-primary.cross_mean_xor(k)-primary.mean_gain(k))<1e-8);
end
writetable(primary,fullfile(out,'t04-mechanism.csv'));
frozen=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');
rows=cell(0,6);m=["seed","within_full","cross","matlab_geom","matlab_geom_within"];
for domain=["Oxford","LEMS"]
    for scope=["all","R2+"]
        for method=m
            sel=obs.dataset==domain & obs.budget==256 & obs.deadline==100 & obs.method==method;
            if scope=="R2+",sel=sel & ismember(obs.id,frozen.id(frozen.dataset==domain & frozen.rings>=2));end
            calls=nnz(sel);success=nnz(sel & obs.status=="success");
            rows(end+1,:)={domain,scope,method,calls,success,success/calls};
        end
    end
end
cov=cell2table(rows,'VariableNames',{'dataset','scope','method','scheduled_calls','timely','rate'});writetable(cov,fullfile(out,'t05-delivery.csv'));
if isfile(fullfile(folder,'structural_cost.csv'))
    cost=read('structural_cost.csv');rows=cell(0,8);
    for domain=["Oxford","LEMS"]
        x=cost(cost.dataset==domain & cost.budget==256,:);ok=isfinite(x.legal_xor);
        recovered=ok & x.rejected>0;extra=x.legal_xor-x.initial_xor;
        rows(end+1,:)={domain,height(x),nnz(ok & ~recovered),nnz(recovered),nnz(~ok),sum(extra(recovered)),mean(extra(recovered)),mean(extra(ok))};
    end
    t=cell2table(rows,'VariableNames',{'dataset','offered','first_legal','recovered','no_legal','total_recovery_cost','mean_cost_on_recovered','mean_cost_on_legal'});
    writetable(t,fullfile(out,'t06-repair.csv'));
end
sel=summary.scope=="R2+" & summary.method=="cross" & summary.baseline=="within_full";
q=summary(sel & ((summary.budget==256 & summary.deadline==200) | (summary.budget~=256 & summary.deadline==100)),:);writetable(q,fullfile(out,'t07-supplements.csv'));
end

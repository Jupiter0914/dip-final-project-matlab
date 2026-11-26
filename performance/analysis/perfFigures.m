function perfFigures(root,mode)
%开发图只读取开发记录，正式图从已经复算的独立实验表取数
out=fullfile(root,'perf_results','output');if ~isfolder(out),mkdir(out);end
figdir=fullfile(out,'figures');if ~isfolder(figdir),mkdir(figdir);end
font='SimSun';dev="dev1";if isfile(fullfile(root,'perf_results','dev2','decision.json')),dev="dev2";end
gateFile=fullfile(root,'perf_results',dev,'gate.csv');assert(isfile(gateFile),'PERF:GateMissing','Complete the engineering gate first');
gate=readtable(gateFile,'TextType','string');g=gate(gate.scope=="all",:);
profiling=profiles(root);assert(any(profiling.implementation=="reference") && any(profiling.implementation==dev),'PERF:MissingProfile','Reference and selected development profiles must both be present');writetable(profiling,fullfile(figdir,'01-hotspots-data.csv'));
f=board();tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');ax=nexttile(tl);
impl=unique(profiling.implementation,'stable');parts=unique(profiling.stage,'stable');values=zeros(numel(parts),numel(impl));
for k=1:numel(impl),for j=1:numel(parts),values(j,k)=sum(profiling.self_s(profiling.stage==parts(j) & profiling.implementation==impl(k)));end;end
barh(ax,values);grid(ax,'on');set(ax,'YTick',1:numel(parts),'YTickLabel',parts,'FontName',font);xlabel(ax,'函数自身耗时 / s（开发剖析）','FontName',font);legend(ax,impl,'Location','southoutside','Interpreter','none','Orientation','horizontal');
ax=nexttile(tl);hold(ax,'on');g=sortrows(g,{'method','metric'});n=height(g);
for k=1:n
    plot(ax,[g.ci95_low(k) g.ci95_high(k)],[k k],'-','Color',[.1 .4 .46]);
    plot(ax,g.ratio(k),k,'o','MarkerFaceColor',[.1 .4 .46],'Color',[.1 .4 .46]);
end
xline(ax,1,':');set(ax,'YTick',1:n,'YTickLabel',g.method+" / "+g.metric,'TickLabelInterpreter','none','YLim',[.5 n+.5]);xlabel(ax,'开发源时间比（快版 / 参考）及95%区间','FontName',font);
saveBoth(f,figdir,'01-hotspots');writetable(g,fullfile(figdir,'01-engineering-data.csv'));
drawFlow(figdir,dev);
if strcmpi(mode,'development')
    eq=jsondecode(fileread(fullfile(root,'perf_results',dev,'equivalence.json')));assert(eq.passed && eq.mismatches==0);
    names=["开发输入";"合成夹具";"核对调用";"核对轮次";"输出文件";"轨迹差异"];
    values=[eq.sources;eq.synthetic;eq.calls;eq.rounds;eq.outputs;eq.mismatches];
    writetable(table(names,values,'VariableNames',{'metric','count'}),fullfile(figdir,'development-equivalence.csv'));
    f=board();tl=tiledlayout(f,1,2,'TileSpacing','compact');ax=nexttile(tl);axis(ax,[0 1 0 7]);axis(ax,'off');
    for j=1:numel(names)
        text(ax,.05,7-j,names(j),'FontName','SimSun','FontSize',12);
        text(ax,.85,7-j,string(values(j)),'HorizontalAlignment','right','FontName','Times New Roman','FontSize',12);
    end
    title(ax,'逐轮内容与真实文件复核','FontName','SimSun');ax=nexttile(tl);hold(ax,'on');
    total=g(g.metric=="total",:);n=height(total);plot(ax,total.s1,(1:n)-.15,'o',total.s2,1:n,'s',total.s3,(1:n)+.15,'d','LineWidth',1.1);xline(ax,1,':');grid(ax,'on');
    set(ax,'YTick',1:n,'YTickLabel',total.method,'YLim',[.5 n+.5],'TickLabelInterpreter','none');xlabel(ax,'各进程固定工作量时间比','FontName','SimSun');
    legend(ax,{'S1','S2','S3'},'Location','southoutside','Orientation','horizontal');saveBoth(f,figdir,'development-equivalence-and-sessions');
    decision=jsondecode(fileread(fullfile(root,'perf_results',dev,'decision.json')));
    decisionTable=table(dev,string(decision.decision),'VariableNames',{'development_round','gate_decision'});writetable(decisionTable,fullfile(figdir,'development-status.csv'));
    verifyPerfFigures(figdir,["01-hotspots","development-equivalence-and-sessions","algorithm-flow"]);
    archive=fullfile(out,'development',dev);if ~isfolder(archive),mkdir(archive);end
    for name=["01-hotspots.png","01-hotspots.svg","01-hotspots-data.csv","01-engineering-data.csv","development-equivalence.csv", ...
            "development-equivalence-and-sessions.png","development-equivalence-and-sessions.svg","algorithm-flow.png","algorithm-flow.svg","development-status.csv","figure_verification.csv"]
        copyfile(fullfile(figdir,name),fullfile(archive,name));
    end
    return
end
rd=@(name)readtable(fullfile(out,name),'TextType','string');
r=rd('fixed_common_receipts.csv');r=r(r.method=="cross" & r.same_file,:);
assert(~isempty(r),'PERF:NoCommonFile','No common fixed-work cross checkpoint');
r.delta=r.fast_received_ms-r.old_received_ms;[groups,roundId]=findgroups(r.round);c=table(roundId,splitapply(@numel,r.round,groups),splitapply(@median,r.old_received_ms,groups),splitapply(@median,r.fast_received_ms,groups),splitapply(@median,r.delta,groups),...
    'VariableNames',{'round','n_common_files','old_median_ms','fast_median_ms','median_paired_delta_ms'});writetable(c,fullfile(figdir,'02-receipts-data.csv'));
f=board();tl=tiledlayout(f,1,2,'TileSpacing','compact');ax=nexttile(tl);
plot(ax,c.round,c.old_median_ms,'-o',c.round,c.fast_median_ms,'-s','LineWidth',1.4);grid(ax,'on');xlabel(ax,'固定工作量的接收轮次','FontName',font);ylabel(ax,'同字节文件的实收时刻中位数 / ms','FontName',font);legend(ax,{'参考','快版'},'FontName',font,'Location','northwest');
%同轮同次且字节相同的事件计算配对实收差，图中标示全部这些事件的中位数
ax=nexttile(tl);hold(ax,'on');bar(ax,c.round,c.median_paired_delta_ms,'FaceColor',[.03 .42 .43]);yline(ax,0,':');grid(ax,'on');xlabel(ax,'固定工作量的接收轮次','FontName',font);ylabel(ax,'同次实收时延差中位数 / ms','FontName',font);saveBoth(f,figdir,'02-receipts');
q=rd('timed_quality.csv');cv=rd('timed_coverage.csv');
primary=q.method=="fast_cross" & q.deadline==100 & ((q.baseline=="fast_within" & q.scope=="R2+") | (ismember(q.baseline,["fast_geom","fast_geom_within"]) & q.scope=="all"));
quality=q(primary,:);coverage=cv(cv.deadline==100 & cv.scope=="all",:);writetable(quality,fullfile(figdir,'03-quality-data.csv'));writetable(coverage,fullfile(figdir,'03-coverage-data.csv'));
obs=rd('timed_observations.csv');obs=obs(obs.deadline==100,:);[groups,methods]=findgroups(obs.method);
coverageMethod=table(methods,splitapply(@numel,obs.rep,groups),splitapply(@sum,double(obs.status=="success"),groups),'VariableNames',{'method','calls','timely'});writetable(coverageMethod,fullfile(figdir,'03-method-coverage.csv'));
f=board();tl=tiledlayout(f,1,2,'TileSpacing','compact');ax=nexttile(tl);barh(ax,100*coverageMethod.timely./coverageMethod.calls,'FaceColor',[.05 .40 .42]);set(ax,'YTick',1:height(coverageMethod),'YTickLabel',coverageMethod.method,'TickLabelInterpreter','none');xlabel(ax,'全部调用的100 ms及时交付率 / %','FontName',font);grid(ax,'on');
ax=nexttile(tl);hold(ax,'on');
for k=1:height(quality)
    lo=quality.ci95_low(k);hi=quality.ci95_high(k);if quality.scope(k)=="R2+",lo=quality.ci975_low(k);hi=quality.ci975_high(k);end
    line(ax,[lo hi],[k k],'Color',[.14 .40 .45]);plot(ax,quality.mean_gain(k),k,'o','Color',[.09 .35 .4],'MarkerFaceColor',[.09 .35 .4]);
end
set(ax,'YTick',1:height(quality),'YTickLabel',quality.baseline+" (n="+quality.n_sources+")",'TickLabelInterpreter','none','YLim',[.5 height(quality)+.5]);xline(ax,0,':');xlabel(ax,'对照错分减去快版跨圈错分 / 像素','FontName',font);saveBoth(f,figdir,'03-quality-coverage');
s=rd('timed_by_source.csv');s=s(s.method=="fast_cross" & s.baseline=="fast_within" & s.scope=="R2+" & s.deadline==100,:);s=sortrows(s,{'mean_value','id'});writetable(s,fullfile(figdir,'04-effects-data.csv'));
f=board();tl=tiledlayout(f,1,2,'TileSpacing','compact');ax=nexttile(tl);plot(ax,1:height(s),s.mean_value,'.','Color',[.02 .40 .42],'MarkerSize',9);yline(ax,0,':');grid(ax,'on');xlabel(ax,'多环源按错分差排序','FontName',font);ylabel(ax,'圈内错分减去跨圈错分 / 像素','FontName',font);
ax=nexttile(tl);st=rd('timed_sessions.csv');st=st(st.method=="fast_cross" & st.baseline=="fast_within" & st.scope=="R2+" & st.deadline==100,:);hold(ax,'on');
for j=1:height(st)
    plot(ax,[st.ci95_low(j) st.ci95_high(j)],[j j],'-','Color',[.09 .40 .44]);plot(ax,st.mean_gain(j),j,'o','Color',[.09 .40 .44],'MarkerFaceColor',[.09 .40 .44]);
end
set(ax,'YTick',1:height(st),'YTickLabel',"S"+st.session,'YLim',[.5 height(st)+.5]);xline(ax,0,':');xlabel(ax,'会话源均差及95%区间 / 像素','FontName',font);saveBoth(f,figdir,'04-source-effects');
replayCases(root,out,figdir,s);
verifyPerfFigures(figdir,["01-hotspots","02-receipts","03-quality-coverage","04-source-effects","algorithm-flow"]);
end

function data=profiles(root)
folder=fullfile(root,'perf_results','profiling');dirs=dir(folder);data=table();
for d=1:numel(dirs)
    csv=fullfile(folder,dirs(d).name,'functions.csv');if ~isfile(csv),continue;end
    t=readtable(csv,'TextType','string');path=lower(replace(t.file,"\","/"));name=lower(t.function_name);
    stage=repmat("其他本项目函数",height(t),1);stage(contains(path,"topology/"))="结构验收";stage(contains(path,"contours/"))="轮廓与回填";
    stage(contains(path,"allocation/") | contains(name,"hierarchy"))="初始化及分配";
    stage(contains(path,"optimization/") | contains(name,"efcandidates") | contains(name,"efstep"))="删插候选与验收";
    stage(endsWith(path,"/efsinglechanges.m"))="单项离散评分";
    stage(contains(path,"baselines/"))="几何起点";stage(contains(path,"codec/") | contains(name,"receive"))="编解码与交付";
    implementation=string(dirs(d).name);
    if implementation=="selected"
        chosen=jsondecode(fileread(fullfile(root,'performance','selected_kernel.json')));implementation=string(chosen.version);
    end
    [g,labels]=findgroups(stage);part=table(repmat(implementation,numel(labels),1),labels,splitapply(@sum,t.self_s,g),'VariableNames',{'implementation','stage','self_s'});
    if isempty(data),data=part;else,data=[data;part];end
end
assert(~isempty(data),'PERF:NoProfile','No developer profiling table');
end

function f=board()
f=figure('Visible','off','Units','centimeters','Position',[2 2 21 10],'Color','white','DefaultAxesFontName','Times New Roman','DefaultTextFontName','SimSun');
end

function saveBoth(f,out,name)
clean=onCleanup(@()close(f));print(f,fullfile(out,[name '.png']),'-dpng','-r320');print(f,fullfile(out,[name '.svg']),'-dsvg','-painters');
end

function drawFlow(out,dev)
f=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 19 14]);ax=axes(f,'Position',[.02 .03 .96 .94],'XLim',[0 100],'YLim',[0 100],'Visible','off');hold(ax,'on');
box(33,94,'独立编码，从合法初解开始同步交付');box(33,81,'建立各环的版本和候选缓存');
diamond(33,68,'轮次与时间允许继续？');box(33,55,'读取或重算各环单删、单插与弧索引');
box(33,42,'重新排列全部合法组合，取前24');diamond(33,29,'本轮有少错且结构合法的候选？');
box(76,29,'停止并返回');box(33,16,'更新改变的环，递增版本并交付');
for y=[90 77 64 51 38 25],arrow([33 y;33 y-5]);end
arrow([54.5 68;85 68;85 33]);text(ax,62,70,'否','FontName','SimSun');text(ax,35,62,'是','FontName','SimSun');
arrow([54.5 29;64 29]);text(ax,58,31,'否','FontName','SimSun');text(ax,35,23,'是','FontName','SimSun');
arrow([11.5 16;4 16;4 68;11.5 68]);text(ax,4.3,39,'下一轮','FontName','SimSun');
labels={'版本相同时复用单项信息','版本变化后重新计算','跨圈会使两个环的缓存失效','每次调用独立建立缓存'};
if dev=="dev2",labels=[labels,{'原格点合并奇偶翻转与边界','超限时退回完整回填'}];end
text(ax,57,53,labels,'FontName','SimSun','FontSize',9);
text(ax,12,5,'限时实验每轮开始检查200 ms上限，固定工作量实验最多八轮并允许自然停止','FontName','SimSun','FontSize',9);
saveBoth(f,out,'algorithm-flow');
    function box(x,y,label)
        w=43;if x>60,w=24;end
        rectangle(ax,'Position',[x-w/2 y-4 w 8],'FaceColor',[.92 .96 .95],'EdgeColor',[.06 .36 .38]);text(ax,x,y,label,'HorizontalAlignment','center','FontName','SimSun','FontSize',10);
    end
    function diamond(x,y,label)
        patch(ax,x+[-21.5 0 21.5 0],y+[0 4 0 -4],[.87 .94 .93],'EdgeColor',[.06 .36 .38]);text(ax,x,y,label,'HorizontalAlignment','center','FontName','SimSun','FontSize',9);
    end
    function arrow(points)
        plot(ax,points(:,1),points(:,2),'-','Color',[.08 .35 .37]);
        v=points(end,:)-points(end-1,:);v=v/norm(v);u=[-v(2) v(1)];tip=points(end,:);
        head=[tip;tip-v*1.4+u*.6;tip-v*1.4-u*.6];patch(ax,head(:,1),head(:,2),[.08 .35 .37],'EdgeColor','none');
    end
end

function replayCases(root,out,figdir,s)
%从源级选择中位正改善、最接近零及最差，再取同方向且最接近该源均差的实际文件
z=readtable(fullfile(out,'timed_pairs.csv'),'TextType','string');z=z(z.method=="fast_cross" & z.baseline=="fast_within" & z.deadline==100 & z.common,:);
manifest=readtable(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv'),'TextType','string');
s=sortrows(s,'id');classes=["positive_median","closest_zero","worst"];selection=table();availability=repmat("no_paired_source",3,1);folder=fullfile(figdir,'cases');if ~isfolder(folder),mkdir(folder);end
for k=1:3
    if isempty(s),continue;end
    if k==1
        candidates=find(s.mean_value>0);if isempty(candidates),availability(k)="no_positive_source";continue;end
        [~,i]=min(abs(s.mean_value(candidates)-median(s.mean_value(candidates))));index=candidates(i);
    elseif k==2
        [~,index]=min(abs(s.mean_value));
    else
        [~,index]=min(s.mean_value);
    end
    availability(k)="file_pair_saved";subject=s(index,:);trials=sortrows(z(z.id==subject.id,:),{'session','rep'});
    same=sign(trials.gain)==sign(subject.mean_value);if any(same),trials=trials(same,:);end
    [~,ii]=min(abs(trials.gain-subject.mean_value));trial=trials(ii,:);trial.source_gain=subject.mean_value;trial.selection=classes(k);
    raw=readFrozenMask(root,manifest(manifest.id==trial.id,:));caseDir=fullfile(folder,classes(k));if ~isfolder(caseDir),mkdir(caseDir);end
    imwrite(raw,fullfile(caseDir,'input.png'));
    for mode=["old","fast"]
        digest=trial.(mode+"_sha256");path=fullfile(root,'local','perf','blobs',digest+".pm3");bytes=readBytes(path);
        assert(numel(bytes)==trial.(mode+"_nbytes") && sha256Bytes(bytes)==digest);decoded=decodePM31(bytes);assert(nnz(raw~=decoded)==trial.(mode+"_xor"));
        if mode=="old",name="fast_within";else,name="fast_cross";end
        copyfile(path,fullfile(caseDir,name+".pm3"));imwrite(decoded,fullfile(caseDir,name+"-decoded.png"));
        idx=1+double(decoded&raw)+2*double(decoded&~raw)+3*double(~decoded&raw);rgb=uint8([249 249 245;96 112 121;218 111 40;45 117 171]);
        imwrite(reshape(rgb(idx(:),:),[size(raw),3]),fullfile(caseDir,name+"-errors.png"));
    end
    if isempty(selection),selection=trial;else,selection=[selection;trial];end
end
writetable(table(classes.',availability,'VariableNames',{'selection','status'}),fullfile(folder,'selection_status.csv'));
if ~isempty(selection),writetable(selection,fullfile(folder,'cases.csv'));end
end

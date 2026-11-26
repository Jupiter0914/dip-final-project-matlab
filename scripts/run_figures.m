function manifest = run_figures(root)
%绘图只读取已保存的观察和文件，不重新启动编码器
if nargin<1, root=fileparts(fileparts(mfilename('fullpath'))); end
addpath(genpath(fullfile(root,'src')));
out=fullfile(root,'figures'); data=fullfile(out,'data');
if ~isfolder(data), mkdir(data); end
ids=["algorithm-flow";"01-encoding";"02-exchange";"03-source-effects";"04-coverage-comparators";"05-structure";"06-cases"];
captions=["合法文件的同步交付、判断分支与优化循环";"编码步骤及一条实际跨圈方法接收时间线";"一次真实跨圈动作的前后轮廓、错分和码长";"不同来源的逐源差及独立会话结果";"各方法按时交付率与Oxford配对错分差";"结构恢复的误差代价及一个匹配孔的变化";"按源均差选择的正改善、近零与最差源及其配对文件"];
manifest=table(ids,captions,"figures/"+ids+".png","figures/"+ids+".svg",repmat("awaiting_formal_results",7,1),strings(7,1),...
    'VariableNames',{'id','caption','png','svg','status','evidence'});
draw_algorithm_flow(out);
manifest.status(1)="generated"; manifest.evidence(1)="scripts/draw_algorithm_flow.m";
indexFile=fullfile(root,'figures','figure_manifest.csv');writetable(manifest,indexFile);
run_result_tables(root);
obsFile=fullfile(root,'results','observations.csv');
if ~isfile(obsFile), verify_figure_outputs(root); return; end
obs=readtable(obsFile,'TextType','string');
assert(height(obs)==24336,'DIP:IncompleteGrid','Expected all 24336 deadline observations before rendering formal figures');
events=readtable(fullfile(root,'results','events.csv'),'TextType','string');
pairs=readtable(fullfile(root,'results','source_pairs.csv'),'TextType','string');
summary=readtable(fullfile(root,'results','summary.csv'),'TextType','string');
coverage=readtable(fullfile(root,'results','coverage.csv'),'TextType','string');
sources=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');
pairKey=pairs.budget==256 & pairs.deadline==100 & pairs.method=="cross" & pairs.baseline=="within_full" & pairs.rings>=2 & isfinite(pairs.gain);
mainPairs=pairs(pairKey,:);
ev=events(events.budget==256 & events.method=="cross" & events.dataset=="Oxford",:);
if ~isempty(ev)
    ordered=sortrows(ev,{'id','session','rep','round'});
    ev=ordered;
    validMove=ev.round>0 & isfinite(ev.donor) & isfinite(ev.receiver) & ev.donor~=ev.receiver;
    moveIndex=find(validMove & ev.received_ms<=100 & ev.id=="Ragdoll_32" & ev.round==1 & ev.donor==1 & ev.receiver==0,1);
    if isempty(moveIndex),moveIndex=find(validMove & ev.received_ms<=100,1);end
    if isempty(moveIndex),moveIndex=find(validMove,1);end
    timelineIndex=moveIndex;
    if isempty(timelineIndex), timelineIndex=1; end
    run=ev(timelineIndex,:);
    sequence=ev(ev.id==run.id & ev.session==run.session & ev.rep==run.rep,:);
    trace=sequence(:,{'dataset','id','session','rep','budget','method','round','received_ms','nbytes','xor','sha256'});
    writetable(trace,fullfile(data,'01-encoding.csv'));
    row=lookup(sources,run.dataset,run.id);raw=readFrozenMask(root,row);
    [dense,~]=extractRings(raw);first=sequence(1,:);
    [~,simple]=decodePM31(readBytes(fullfile(root,'local','blobs',first.sha256+".pm3")));
    ready=sequence(sequence.received_ms<=100,:);
    f=canvas(18,12);guard=onCleanup(@() close(f));tl=tiledlayout(f,2,4,'TileSpacing','compact','Padding','compact');
    for stage=1:4
        ax=nexttile(tl,stage);hold(ax,'on');
        if stage==1
            imagesc(ax,raw,[0 1]);colormap(ax,[.98 .98 .96;.21 .29 .31]);caption="原始二值蒙版";
        elseif stage==2 || stage==3
            if stage==2,rings=dense;caption="0.25等值线";else,rings=simple;caption="分配顶点后交付初解";end
            for ri=1:numel(rings)
                pts=rings{ri}([1:end 1],:)/4;
                if stage==2,plot(ax,pts(:,1),pts(:,2),'-','Color',[.08 .35 .38],'LineWidth',.6);
                else,plot(ax,pts(:,1),pts(:,2),'-o','Color',[.08 .35 .38],'LineWidth',.75,'MarkerSize',2);end
            end
        else
            if isempty(ready)
                text(ax,size(raw,2)/2,size(raw,1)/2,'截止前尚未收到文件','HorizontalAlignment','center','FontName','SimSun');caption="100 ms 接收端";
            else
                received=decodePM31(readBytes(fullfile(root,'local','blobs',ready.sha256(end)+".pm3")));
                image(ax,errorRgb(raw,received));caption="删插并验收后实收";
            end
        end
        axis(ax,'image');set(ax,'YDir','reverse','XLim',[.5 size(raw,2)+.5],'YLim',[.5 size(raw,1)+.5]);axis(ax,'off');title(ax,caption,'FontName','SimSun','FontSize',10);
    end
    ax=nexttile(tl,5,[1 4]);stairs(ax,sequence.received_ms,sequence.xor,'-o','Color',[.04 .38 .40],'LineWidth',1.5);
    xline(ax,100,'--','100 ms');xline(ax,200,':','200 ms');xlim(ax,[0 1.05*max([210;sequence.received_ms])]);grid(ax,'on');
    cnlabel(ax,'接收时间 / ms','错分像素数');
    title(ax,run.id+"  ·  会话 "+string(run.session)+"  ·  重复 "+string(run.rep),'Interpreter','none','FontName','SimSun');
    output(f,out,ids(2));clear guard
    manifest.status(2)="generated";manifest.evidence(2)="figures/data/01-encoding.csv";
    if ~isempty(moveIndex)
        after=run;before=sequence(sequence.round<after.round,:);
        assert(~isempty(before),'DIP:MissingCheckpoint','An accepted move has no preceding checkpoint');
        before=before(end,:);
        src=lookup(sources,after.dataset,after.id);
        raw=readFrozenMask(root,src);
        [a,ar]=caseFile(root,before,raw,fullfile(data,'case02'),'before');
        [b,br]=caseFile(root,after,raw,fullfile(data,'case02'),'after');
        assert(after.nbytes==before.nbytes && nnz(raw~=b)<nnz(raw~=a),'DIP:MoveReplay','Real exchange violated file length or error decrease');
        %由相邻两份文件确定删点和补点，不依赖日志采用零基还是一基环编号
        count0=cellfun(@(v) size(v,1),ar);count1=cellfun(@(v) size(v,1),br);
        donor=find(count1-count0==-1);receiver=find(count1-count0==1);
        assert(isscalar(donor)&&isscalar(receiver)&&all(abs(count1-count0)<=1),'DIP:MoveReplay','Incorrect ring transfer');
        removed=setdiff(ar{donor},br{donor},'rows');added=setdiff(br{receiver},ar{receiver},'rows');
        assert(size(removed,1)==1 && size(added,1)==1,'DIP:MoveReplay','Cannot identify one removed and one inserted point');
        assert(after.donor==donor-1 && after.receiver==receiver-1 && isequal([after.deleted_x after.deleted_y],removed) && isequal([after.inserted_x after.inserted_y],added),'DIP:MoveReplay','Logged ring IDs or coordinates disagree with actual files');
        %扩展画布上的零基四倍坐标除以四后，恰好就是原图上的一基像素中心坐标
        f=canvas(15,14);guard=onCleanup(@() close(f));tl=tiledlayout(f,2,2,'TileSpacing','compact');
        for i=1:2
            if i==1, c=removed;ri=donor;symbol='x';label="删点";else,c=added;ri=receiver;symbol='+';label="补点";end
            for j=1:2
                ax=nexttile(tl);if j==1, m=a;rr=ar;heading="操作前";else,m=b;rr=br;heading="操作后";end
                image(ax,errorRgb(raw,m));axis(ax,'image');axis(ax,'off');hold(ax,'on');
                pts=rr{ri}([1:end 1],:)/4;
                plot(ax,pts(:,1),pts(:,2),'-o','Color',[.09 .26 .30],'MarkerSize',2);
                plot(ax,c(1)/4,c(2)/4,symbol,'Color',[.68 .14 .15],'LineWidth',2,'MarkerSize',10);
                xlim(ax,c(1)/4+[-26.5 26.5]);ylim(ax,c(2)/4+[-26.5 26.5]);title(ax,label+" · "+heading,'FontName','SimSun');
            end
        end
        title(tl,{char(after.id),sprintf('%d → %d 像素   %d → %d 字节   %.1f → %.1f ms',before.xor,after.xor,before.nbytes,after.nbytes,before.received_ms,after.received_ms)},'FontName','SimSun','Interpreter','none');
        xlabel(tl,'橙色为多填，蓝色为漏填。叉号为删点，加号为补点','FontName','SimSun');
        output(f,out,ids(3));clear guard
        details=[before;after];writetable(details,fullfile(data,'02-exchange.csv'));
        manifest.status(3)="generated";manifest.evidence(3)="figures/data/02-exchange.csv + figures/data/case02";
    else
        manifest.status(3)="no_observed_cross_ring_exchange";
    end
else
    manifest.status(2:3)="no_received_oxford_cross_file";
end
if ~isempty(mainPairs)
    drawEffects(root,out,data,mainPairs,obs,ids(4));
    manifest.status(4)="generated";manifest.evidence(4)="figures/data/03-source-effects.csv + 03-session-intervals.csv";
else
    manifest.status(4)="no_equal_length_timely_multiring_pair";
end
drawCoverage(out,data,coverage,summary,ids(5));
manifest.status(5)="generated";manifest.evidence(5)="figures/data/04-coverage.csv + 04-comparators.csv";
manifest.status(6)=drawStructure(root,out,data,obs,sources,ids(6));
if manifest.status(6)=="generated",manifest.evidence(6)="figures/data/05-repair.csv + 05-hole.csv + case05";end
manifest.status(7)=drawCases(root,out,data,obs,sources,mainPairs,ids(7));
if startsWith(manifest.status(7),"generated"),manifest.evidence(7)="figures/data/06-case-selection.csv + 06-cases.csv + case06*";end
writetable(manifest,indexFile);
verify_figure_outputs(root);
end

function f=canvas(w,h)
f=figure('Visible','off','Color','white','Units','centimeters','Position',[1 1 w h]);
set(f,'DefaultAxesFontName','Times New Roman','DefaultAxesFontSize',10,'DefaultTextFontName','SimSun');
end

function output(f,out,key)
set(f,'PaperPositionMode','auto');print(f,fullfile(out,key+".png"),'-dpng','-r320');
print(f,fullfile(out,key+".svg"),'-dsvg','-painters');
end

function cnlabel(ax,x,y)
xlabel(ax,x,'FontName','SimSun');ylabel(ax,y,'FontName','SimSun');
end

function row=lookup(sources,dataset,id)
row=sources(sources.dataset==dataset & sources.id==id,:);
assert(height(row)==1,'DIP:SourceIdentity','Source ID is missing or ambiguous');
end

function [mask,rings]=caseFile(root,row,raw,folder,tag)
if ~isfolder(folder),mkdir(folder);end
file=fullfile(root,'local','blobs',row.sha256+".pm3");
fid=fopen(file,'rb');assert(fid>=0,'DIP:MissingBlob','Missing PM31 %s',file);
closer=onCleanup(@() fclose(fid));bytes=fread(fid,Inf,'*uint8');clear closer
assert(numel(bytes)==row.nbytes && strcmp(sha256Bytes(bytes),row.sha256),'DIP:BlobIntegrity','File length or SHA-256 mismatch');
[mask,rings]=decodePM31(bytes);
assert(isequal(size(mask),size(raw)) && nnz(mask~=raw)==row.xor,'DIP:PixelReplay','Decoded pixels disagree with recorded metrics');
copyfile(file,fullfile(folder,string(tag)+".pm3"));
imwrite(raw,fullfile(folder,'input.png'));imwrite(mask,fullfile(folder,string(tag)+"-decoded.png"));
imwrite(errorRgb(raw,mask),fullfile(folder,string(tag)+"-errors.png"));
end

function rgb=errorRgb(raw,mask)
%多填画橙色，漏填画蓝色，正确前景画深灰色
classes=1+double(raw & mask)+2*double(~raw & mask)+3*double(raw & ~mask);
colors=uint8([249 249 245;96 112 121;218 111 40;45 117 171]);
rgb=reshape(colors(classes(:),:),[size(raw) 3]);
end

function drawEffects(root,out,data,pairs,~,key)
writetable(pairs,fullfile(data,'03-source-effects.csv'));
summary=readtable(fullfile(root,'results','summary.csv'),'TextType','string');
sessions=readtable(fullfile(root,'results','session_summary.csv'),'TextType','string');
cluster=readtable(fullfile(root,'results','category_sensitivity.csv'),'TextType','string');
main=@(t)t.budget==256 & t.deadline==100 & t.method=="cross" & t.baseline=="within_full" & t.scope=="R2+";
allStats=summary(main(summary),:);sStats=sessions(main(sessions),:);cluster=cluster(main(cluster),:);
f=canvas(18,15);guard=onCleanup(@() close(f));tl=tiledlayout(f,2,2,'TileSpacing','compact');allRows=cell(0,6);
for domain=["Oxford","LEMS"]
    values=sort(pairs.gain(pairs.dataset==domain));
    ax=nexttile(tl);plot(ax,1:numel(values),values,'.','MarkerSize',9,'Color',[.02 .38 .40]);
    yline(ax,0,'-','Color',[.55 .55 .55]);grid(ax,'on');cnlabel(ax,'按改善量排序的源','少错像素数');
    title(ax,domain+"  (n = "+numel(values)+")",'FontName','Times New Roman');
    total=allStats(allStats.dataset==domain,:);sub=sortrows(sStats(sStats.dataset==domain,:),'session');
    labels=["全部";"S"+string(sub.session)];n=[total.n_sources;sub.n_sources];
    m=[total.mean_gain;sub.mean_gain];lo=[total.ci_low;sub.ci_low];hi=[total.ci_high;sub.ci_high];
    if domain=="LEMS" && ~isempty(cluster)
        labels(end+1)="类别整簇";n(end+1)=total.n_sources;
        m(end+1)=total.mean_gain;lo(end+1)=cluster.cluster_low(1);hi(end+1)=cluster.cluster_high(1);
    end
    ax=nexttile(tl);hold(ax,'on');
    for k=1:numel(labels)
        if isfinite(m(k))
            plot(ax,[lo(k) hi(k)],[k k],'-','LineWidth',1.2,'Color',[.15 .40 .49]);
            plot(ax,m(k),k,'o','Color',[.15 .40 .49],'MarkerFaceColor',[.15 .40 .49]);
        end
        allRows(end+1,:)={domain,labels(k),n(k),m(k),lo(k),hi(k)};
    end
    xline(ax,0,':');set(ax,'YDir','reverse','YTick',1:numel(labels),'YTickLabel',labels,'FontName','SimSun','YLim',[.5 numel(labels)+.5]);
    xlabel(ax,'平均少错与95%区间','FontName','SimSun');
end
stats=cell2table(allRows,'VariableNames',{'dataset','scope','n_sources','mean_gain','ci_low','ci_high'});
writetable(stats,fullfile(data,'03-session-intervals.csv'));output(f,out,key);
end

function t=matchRuns(obs)
%同一来源、会话、重复和预算且实际字节数相同，才允许比较像素差
ok=isfinite(obs.xor) & obs.nbytes>=10 & ~ismissing(string(obs.sha256)) & strlength(string(obs.sha256))==64 & obs.received_ms<=obs.deadline;
keys={'dataset','id','session','rep','budget','deadline'};
fields={'nbytes','xor','sha256','fp','fn','received_ms'};
a=obs(ok & obs.method=="within_full",[keys fields]);
b=obs(ok & obs.method=="cross",[keys fields]);
a=renamevars(a,fields,strcat(fields,'_base'));b=renamevars(b,fields,strcat(fields,'_cross'));
t=innerjoin(a,b,'Keys',keys);t=t(t.nbytes_base==t.nbytes_cross,:);
end

function drawCoverage(out,data,coverage,summary,key)
c=coverage(coverage.budget==256 & coverage.deadline==100,:);
if ismember('scope',c.Properties.VariableNames),c=c(c.scope=="all",:);end
s=summary(summary.dataset=="Oxford" & summary.budget==256 & summary.deadline==100 & summary.method=="cross" & ...
    ((summary.scope=="all" & ismember(summary.baseline,["matlab_geom","matlab_geom_within"])) | (summary.scope=="R2+" & summary.baseline=="within_full")),:);
if ismember('metric',s.Properties.VariableNames),s=s(s.metric=="xor_saved",:);end
writetable(c,fullfile(data,'04-coverage.csv'));writetable(s,fullfile(data,'04-comparators.csv'));
f=canvas(19,9);guard=onCleanup(@() close(f));tl=tiledlayout(f,1,2,'TileSpacing','compact');
ax=nexttile(tl);hold(ax,'on');domains=["Oxford","LEMS"];ms=["seed","matlab_geom","matlab_geom_within","within_full","cross"];
v=NaN(numel(ms),numel(domains));
for i=1:numel(ms)
    for j=1:numel(domains)
        v0=c.rate(c.method==ms(i)&c.dataset==domains(j));if ~isempty(v0),assert(isscalar(v0));v(i,j)=100*v0;end
    end
end
h=barh(ax,v);h(1).FaceColor=[.05 .40 .42];h(2).FaceColor=[.63 .74 .76];
set(ax,'YTick',1:numel(ms),'YTickLabel',ms,'TickLabelInterpreter','none');xlim(ax,[0 100]);xlabel(ax,'全部调用中及时交付的比例 / %','FontName','SimSun');legend(ax,domains,'Location','southoutside','Orientation','horizontal');
ax=nexttile(tl);hold(ax,'on');
for k=1:height(s)
    if isfinite(s.mean_gain(k))
        line(ax,[s.ci_low(k) s.ci_high(k)],[k k],'Color',[.05 .40 .42],'LineWidth',1.3);
        plot(ax,s.mean_gain(k),k,'o','MarkerFaceColor',[.05 .40 .42],'Color',[.05 .40 .42]);
    end
end
xline(ax,0,':');set(ax,'YTick',1:height(s),'YTickLabel',s.baseline+"  (n="+s.n_sources+")",'TickLabelInterpreter','none','YLim',[.5 max(1,height(s))+.5]);
bounds=[s.ci_low(isfinite(s.ci_low));s.ci_high(isfinite(s.ci_high));0];span=max(1,max(bounds)-min(bounds));xlim(ax,[min(bounds)-.08*span,max(bounds)+.08*span]);
xlabel(ax,'Oxford 平均少错像素与95%区间','FontName','SimSun');output(f,out,key);
end

function status=drawStructure(root,out,data,obs,sources,key)
status="missing_initialization_diagnostic";path=fullfile(root,'results','structural_cost.csv');
if ~isfile(path),return;end
cost=readtable(path,'TextType','string');cost=cost(cost.dataset=="Oxford" & cost.budget==256,:);
cost.extra_xor=cost.legal_xor-cost.initial_xor;writetable(cost,fullfile(data,'05-repair.csv'));
%优先选已及时交付且有孔的源，实读其文件重新建立原区与解码区配对
t=obs(obs.dataset=="Oxford" & obs.budget==256 & obs.deadline==100 & obs.method=="cross" & obs.rings>=2 & ...
    isfinite(obs.xor) & obs.received_ms<=obs.deadline & strlength(string(obs.sha256))==64,:);
[~,ix]=unique(t(:,{'dataset','id','sha256'}),'stable');t=t(ix,:);
regionFile=fullfile(root,'results','regions.csv');
if ~isfile(regionFile),status="missing_pixel_recalculation";return;end
regions=readtable(regionFile,'TextType','string');holes=regions(regions.kind==2,:);
candidates=innerjoin(t,holes,'Keys',{'dataset','id','sha256'},'RightVariables',{'reference_id','decoded_id','area_ratio'});
if isempty(candidates),status="no_eligible_confirmed_hole";return;end
candidates=sortrows(candidates,{'area_ratio','id','session','rep','reference_id'});
selected=candidates(1,:);bestRatio=selected.area_ratio;
src=lookup(sources,selected.dataset,selected.id);raw=readFrozenMask(root,src);
[dec,~]=caseFile(root,selected,raw,fullfile(data,'case05'),'cross');
ref=digitalLayout(raw);pred=digitalLayout(dec);fa=ref.bg(2:end-1,2:end-1)==selected.reference_id;fb=pred.bg(2:end-1,2:end-1)==selected.decoded_id;
[r,c]=find(fa|fb);box=[max(1,min(c)-3) min(size(raw,2),max(c)+3) max(1,min(r)-3) min(size(raw,1),max(r)+3)];
selected.reference_label=selected.reference_id;selected.decoded_label=selected.decoded_id;selected.reference_area=nnz(fa);selected.decoded_area=nnz(fb);selected.overlap=nnz(fa&fb);
assert(abs(nnz(fb)/nnz(fa)-bestRatio)<2e-12,'DIP:HoleAudit','Selected hole ratio disagrees with independent decoding');
selected.xmin=box(1);selected.xmax=box(2);selected.ymin=box(3);selected.ymax=box(4);writetable(selected,fullfile(data,'05-hole.csv'));
f=canvas(19,8);guard=onCleanup(@() close(f));tl=tiledlayout(f,1,3,'TileSpacing','compact');
ax=nexttile(tl);v=sort(cost.extra_xor(cost.rejected>0 & isfinite(cost.extra_xor)));bar(ax,1:numel(v),v,'FaceColor',[.15 .40 .49]);grid(ax,'on');cnlabel(ax,'按额外错分排序的恢复源','额外错分像素数');
if ~isempty(v),yline(ax,mean(v),'--',sprintf('%.1f',mean(v)),'Color',[.61 .31 .10]);end
for j=1:2
    ax=nexttile(tl);if j==1,a=fa;label="参考孔";else,a=fb;label="重建孔";end
    imagesc(ax,a(box(3):box(4),box(1):box(2)),[0 1]);colormap(ax,gray(2));axis(ax,'image');axis(ax,'off');title(ax,label+" · "+nnz(a)+" 像素",'FontName','SimSun');
end
xlabel(tl,selected.id+" · 会话 "+selected.session+" · 重复 "+selected.rep+"，孔的解码面积占原面积 "+sprintf('%.1f%%',100*bestRatio),'FontName','SimSun','Interpreter','none');
output(f,out,key);status="generated";
end

function status=drawCases(root,out,data,obs,sources,pairs,key)
p=sortrows(pairs(pairs.dataset=="Oxford",:),'id');status="no_eligible_oxford_multiring_pair";
if isempty(p),return;end
chosen=nan(1,3);positive=find(p.gain>0);zero=find(p.gain==0);negative=find(p.gain<0);
if ~isempty(positive),[~,j]=min(abs(p.gain(positive)-median(p.gain(positive))));chosen(1)=positive(j);end
if ~isempty(zero),chosen(2)=zero(1);end
if ~isempty(negative),[~,j]=min(p.gain(negative));chosen(3)=negative(j);end
classes=["正改善中位附近","持平","最差负差"];
selection=table((1:3).',classes.',[numel(positive);numel(zero);numel(negative)],isfinite(chosen).',...
    'VariableNames',{'figure_column','selection','available_sources','has_case'});
writetable(selection,fullfile(data,'06-case-selection.csv'));
matched=matchRuns(obs(obs.dataset=="Oxford" & obs.budget==256 & obs.deadline==100,:));
f=canvas(18,17);guard=onCleanup(@() close(f));tl=tiledlayout(f,3,3,'TileSpacing','compact');rows=table();
for col=1:3
    if ~isfinite(chosen(col))
        ax=nexttile(tl,col);axis(ax,'off');text(ax,.5,.5,classes(col)+"（该类无观测源）",'HorizontalAlignment','center','FontName','SimSun');continue
    end
    candidate=p(chosen(col),:);options=sortrows(matched(matched.id==candidate.id,:),{'session','rep'});assert(~isempty(options));
    gain=options.xor_base-options.xor_cross;
    if col==1,preferred=find(gain>0);elseif col==3,preferred=find(gain<0);else,preferred=find(gain==0);end
    if isempty(preferred)
        assert(col==2,'DIP:CaseSelection','Nonzero source mean without any same-sign paired repeat');
        preferred=(1:height(options)).';
    end
    [~,nearest]=min(abs(gain(preferred)-candidate.gain));choice=preferred(nearest);
    t=options(choice,:);t.gain_observation=gain(choice);
    raw=readFrozenMask(root,lookup(sources,candidate.dataset,candidate.id));sub=fullfile(data,"case06-"+col);
    for j=1:2
        if j==1,ending="_base";tag="within_full";else,ending="_cross";tag="cross";end
        ev=table(t.("sha256"+ending),t.("nbytes"+ending),t.("xor"+ending),'VariableNames',{'sha256','nbytes','xor'});
        [mask,~]=caseFile(root,ev,raw,sub,tag);masks{j}=mask;
    end
    %用积分图选择两份结果差异最多的同一裁片，持平时选择可见错分最多处
    delta=masks{1}~=masks{2};if ~any(delta,'all'),delta=raw~=masks{1};end
    if ~any(delta,'all'),delta=raw;end
    edge=min([128,size(raw)]);ii=zeros(size(raw)+1);ii(2:end,2:end)=cumsum(cumsum(double(delta),1),2);
    score=ii(edge+1:end,edge+1:end)-ii(1:end-edge,edge+1:end)-ii(edge+1:end,1:end-edge)+ii(1:end-edge,1:end-edge);
    [~,k]=max(score(:));[y,x]=ind2sub(size(score),k);
    t.figure_column=col;t.selection=classes(col);t.gain_source=candidate.gain;t.crop_x=x;t.crop_y=y;t.crop_side=edge;
    if isempty(rows),rows=t;else,rows=[rows;t];end
    ax=nexttile(tl,col);imagesc(ax,raw,[0 1]);colormap(ax,gray(2));axis(ax,'image');axis(ax,'off');
    rectangle(ax,'Position',[x-.5 y-.5 edge edge],'EdgeColor',[.94 .53 .16],'LineWidth',1.2);
    title(ax,{char(candidate.id),sprintf('源均差 %+.2f    所示重复 %+d',candidate.gain,t.gain_observation)},'Interpreter','none','FontName','SimSun','FontSize',8);
    for j=1:2
        ax=nexttile(tl,3*j+col);rgb=errorRgb(raw,masks{j});image(ax,rgb(y:y+edge-1,x:x+edge-1,:));axis(ax,'image');axis(ax,'off');
        if j==1,label="圈内";else,label="跨圈";end
        title(ax,label+" · "+string(nnz(raw~=masks{j}))+" 个错分像素",'FontName','SimSun');
    end
end
xlabel(tl,'橙色为多填，蓝色为漏填。两种方法使用同一窗口','FontName','SimSun');
writetable(rows,fullfile(data,'06-cases.csv'));output(f,out,key);
if all(selection.has_case),status="generated";else,status="generated_partial_classes";end
end

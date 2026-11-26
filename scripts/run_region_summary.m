function run_region_summary(root)
%每条区域记录都带原图和对应文件，仅对同一次实际交付的身份做配对
folder=fullfile(root,'results');
reg=readtable(fullfile(folder,'regions.csv'),'TextType','string');
obs=readtable(fullfile(folder,'observations.csv'),'TextType','string');
obs=obs(obs.status=="success",:);
fileKey={'dataset','id','sha256'};
identity={'dataset','id','kind','reference_id'};
assert(height(unique(reg(:,[fileKey,{'kind','reference_id'}])))==height(reg))
assert(all(ismember(reg.kind,[1 2])))
a=reg.reference_area; d=reg.decoded_area; h=reg.intersection;
assert(all(h>0 & h<=min(a,d) & 2*h>=min(a,d)))
assert(all(abs(reg.recall-h./a)<1e-11 & abs(reg.precision-h./d)<1e-11))
assert(all(abs(reg.area_ratio-d./a)<1e-11 & abs(reg.iou-h./(a+d-h))<1e-11))
assert(height(unique(reg(:,identity)))==height(unique(reg(:,[identity,{'reference_area'}]))))
assert(all(ismember(unique(obs(obs.rings>0,fileKey)),unique(reg(:,fileKey)))))
reg.area_band=areaBand(a);
reg.severe_shrink=double(d*2<a); reg.low_coverage=double(h*2<a);
reg.area_change=d-a;
condition={'dataset','budget','deadline','method','kind'};
bySource=[condition,{'id'}];
fields={'recall','precision','area_ratio','iou','area_change','severe_shrink','low_coverage'};
[G,blob]=findgroups(reg(:,[fileKey,{'kind'}]));
blob.n_regions=splitapply(@numel,reg.reference_id,G);
for name=["recall","precision","area_ratio"]
    blob.("min_"+name)=splitapply(@min,reg.(name),G);
end
blob.ever_shrink=splitapply(@max,reg.severe_shrink,G);
blob.ever_low_coverage=splitapply(@max,reg.low_coverage,G);
stats={'n_regions','min_recall','min_precision','min_area_ratio','ever_shrink','ever_low_coverage'};
trials=innerjoin(obs(:,[fileKey,{'session','rep','budget','deadline','method'}]),blob,'Keys',fileKey);
perSession=groupMeans(trials,[bySource,{'session'}],stats);
perSource=groupMeans(perSession,bySource,stats);
[G,counts]=findgroups(trials(:,bySource));
counts.valid_runs=splitapply(@numel,trials.rep,G);
perSource=innerjoin(perSource,counts,'Keys',bySource);
perSource.Properties.VariableNames{'units'}='valid_sessions';
writetable(perSource,fullfile(folder,'regions_by_source.csv'))
summary=groupMeans(perSource,condition,stats);
summary.Properties.VariableNames{'units'}='sources_with_region';
[G,total]=findgroups(perSource(:,condition));
total.distinct_regions=splitapply(@sum,perSource.n_regions,G);
total.sources_ever_shrink=splitapply(@nnz,perSource.ever_shrink>0,G);
total.sources_ever_low_coverage=splitapply(@nnz,perSource.ever_low_coverage>0,G);
writetable(innerjoin(summary,total,'Keys',condition),fullfile(folder,'regions_summary.csv'))

%同一图中同一面积等级先平均，再依次平均会话内重复和来源
withinBlob=groupMeans(reg,[fileKey,{'kind','area_band'}],fields);
byBand=innerjoin(obs(:,[fileKey,{'session','rep','budget','deadline','method'}]),withinBlob,'Keys',fileKey);
strata=[condition,{'area_band'}];
ss=groupMeans(byBand,[strata,{'id','session'}],fields);
src=groupMeans(ss,[strata,{'id'}],fields);
bands=groupMeans(src,strata,fields); bands.Properties.VariableNames{'units'}='sources_with_region';
writetable(bands,fullfile(folder,'region_area_bands.csv'))

%保存每种条件下最小的召回和面积比，以定位具体原区域、文件及重复
worst=innerjoin(obs(:,[fileKey,{'session','rep','budget','deadline','method'}]), ...
    reg(:,[fileKey,{'kind','reference_id','reference_area','decoded_area','recall','area_ratio'}]),'Keys',fileKey);
critical=[];
for metric=["recall","area_ratio"]
    ordered=sortrows(worst,[condition,{char(metric),'id','reference_id','session','rep'}]);
    [~,ix]=unique(ordered(:,condition),'rows','stable'); chosen=ordered(ix,:);
    chosen.metric=repmat(metric,height(chosen),1);
    if isempty(critical),critical=chosen;else,critical=[critical;chosen];end
end
writetable(critical,fullfile(folder,'region_critical_files.csv'))

main=obs(obs.budget==256 & obs.deadline==100 & obs.rings>=2,:);
key={'dataset','id','session','rep','budget','deadline'};
pairs=pairFiles(main,key);
cmp=[key,{'cross_sha','within_sha','global_gain'}];
first=renameFileVars(reg,'cross'); second=renameFileVars(reg,'within');
r=innerjoin(pairs(:,cmp),first,'Keys',{'dataset','id','cross_sha'});
r=innerjoin(r,second,'Keys',{'dataset','id','within_sha','kind','reference_id','reference_area','area_band'});
assert(height(r)==height(innerjoin(pairs(:,cmp),first,'Keys',{'dataset','id','cross_sha'})))
r.recall_gain_pp=100*(r.cross_recall-r.within_recall);
r.precision_gain_pp=100*(r.cross_precision-r.within_precision);
r.area_ratio_change=r.cross_area_ratio-r.within_area_ratio;
r.severe_abs=double(2*r.cross_decoded_area<r.reference_area);
r.new_severe=double(r.severe_abs>0 & 2*r.within_decoded_area>=r.reference_area);
r.half_baseline=double(2*r.cross_decoded_area<r.within_decoded_area);
r.low_coverage=double(2*r.cross_intersection<r.reference_area);
r.worse_area_error=double(abs(r.cross_decoded_area-r.reference_area)>abs(r.within_decoded_area-r.reference_area));
metrics={'global_gain','cross_recall','within_recall','recall_gain_pp','precision_gain_pp', ...
    'cross_area_ratio','within_area_ratio','area_ratio_change','severe_abs','new_severe','half_baseline','low_coverage','worse_area_error'};
regKey=[identity,{'reference_area','area_band'}];
rs=groupMeans(r,[regKey,{'session'}],metrics);
avg=groupMeans(rs,regKey,metrics); avg.Properties.VariableNames{'units'}='common_sessions';
nr=groupMeans(r,regKey,{}); nr.Properties.VariableNames{'units'}='common_repeats';
writetable(innerjoin(avg,nr,'Keys',regKey),fullfile(folder,'regions_paired.csv'))
bad=r(r.severe_abs>0 | r.new_severe>0 | r.half_baseline>0 | r.low_coverage>0,:);
writetable(bad,fullfile(folder,'region_degradation.csv'))
ss=groupMeans(pairs,{'dataset','id','session'},{'global_gain'});
source=groupMeans(ss,{'dataset','id'},{'global_gain'});
source.Properties.VariableNames{'global_gain'}='source_gain'; source.units=[];
r=innerjoin(r,source,'Keys',{'dataset','id'});
conflicts=r(r.source_gain>0 & r.global_gain>0 & (r.recall_gain_pp<0 | r.worse_area_error>0),:);
writetable(conflicts,fullfile(folder,'region_conflicts.csv'))
end

function band=areaBand(a)
band=repmat("257+",size(a)); band(a<=256)="65-256"; band(a<=64)="17-64"; band(a<=16)="1-16";
end

function t=groupMeans(x,keys,fields)
%空子集照常写表头，避免把没有共同交付的区域填零
if isempty(x)
    t=x([],[keys,fields]); t.units=zeros(0,1); return
end
[g,t]=findgroups(x(:,keys)); t.units=accumarray(g,1);
for i=1:numel(fields)
    f=fields{i}; t.(f)=splitapply(@mean,x.(f),g);
end
end

function pairs=pairFiles(main,key)
c=main(main.method=="cross",[key,{'sha256','xor','nbytes'}]);
w=main(main.method=="within_full",[key,{'sha256','xor','nbytes'}]);
c.Properties.VariableNames(end-2:end)={'cross_sha','cross_xor','cross_bytes'};
w.Properties.VariableNames(end-2:end)={'within_sha','within_xor','within_bytes'};
assert(height(unique(c(:,key)))==height(c) && height(unique(w(:,key)))==height(w))
pairs=innerjoin(c,w,'Keys',key);
pairs=pairs(pairs.cross_bytes==pairs.within_bytes,:);
pairs.global_gain=pairs.within_xor-pairs.cross_xor;
end

function t=renameFileVars(r,prefix)
vars={'decoded_area','intersection','recall','precision','area_ratio','iou'};
t=r(:,[{'dataset','id','sha256','kind','reference_id','reference_area','area_band'},vars]);
t.Properties.VariableNames{'sha256'}=[prefix '_sha'];
for i=1:numel(vars)
    t.Properties.VariableNames{vars{i}}=[prefix '_' vars{i}];
end
end

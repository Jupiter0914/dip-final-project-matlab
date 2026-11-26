function run_quality_summary(root)
%边界与像素指标从已重放的文件取得，所有质量比较按共同成功和同码长配对
folder=fullfile(root,'results');
obs=readtable(fullfile(folder,'observations.csv'),'TextType','string');
obs=obs(obs.status=="success",:);
metrics=readtable(fullfile(folder,'blob_metrics.csv'),'TextType','string');
measure={'fp','fn','xor','iou','rmse','mse','bf1','bf2','bf3'};
metrics.mse=metrics.rmse.^2;
lookup={'dataset','id','sha256'};
z=innerjoin(obs(:,[lookup,{'session','rep','budget','deadline','method','nbytes','rings'}]), ...
    metrics(:,[lookup,measure]),'Keys',lookup);
assert(height(z)==height(obs))
claims=["cross","within_full";"cross","seed";"cross","matlab_geom";"cross","matlab_geom_within"; ...
    "exact","cross";"within_full","matlab_geom_within"];
match={'dataset','id','session','rep','budget','deadline','nbytes','rings'};
allSource={};allSummary={};
for k=1:size(claims,1)
    a=z(z.method==claims(k,1),[match,measure]);b=z(z.method==claims(k,2),[match,measure]);
    a=renamevars(a,measure,string(measure)+"_method");
    b=renamevars(b,measure,string(measure)+"_baseline");
    t=innerjoin(a,b,'Keys',match);
    if isempty(t),continue;end
    values=[string(measure)+"_method",string(measure)+"_baseline"];
    first=groupAverage(t,{'dataset','id','session','budget','deadline','rings'},values);
    s=groupAverage(first,{'dataset','id','budget','deadline','rings'},values);
    s=renamevars(s,'n','valid_sessions');
    s.method=repmat(claims(k,1),height(s),1);s.baseline=repmat(claims(k,2),height(s),1);
    allSource{end+1}=s;
    for scope=["all","R1","R2+"]
        use=true(height(s),1);if scope=="R1",use=s.rings==1;elseif scope=="R2+",use=s.rings>=2;end
        if ~any(use),continue;end
        u=groupAverage(s(use,:),{'dataset','budget','deadline','method','baseline'},values);
        u=renamevars(u,'n','n_sources');
        u.scope=repmat(scope,height(u),1);
        allSummary{end+1}=u;
    end
end
if ~isempty(allSource),writetable(vertcat(allSource{:}),fullfile(folder,'paired_quality_by_source.csv'));end
if ~isempty(allSummary),writetable(vertcat(allSummary{:}),fullfile(folder,'paired_quality_summary.csv'));end
end

function out=groupAverage(t,keys,values)
[g,out]=findgroups(t(:,keys));
for col=values,out.(col)=splitapply(@mean,t.(col),g);end
out.n=splitapply(@numel,t.(values(1)),g);
end

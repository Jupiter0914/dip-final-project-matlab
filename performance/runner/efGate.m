function decision=efGate(root,stage)
%按来源等权合并成对耗时，成功条件与每个排除原因均随表保存
out=fullfile(root,'perf_results',stage);T=readtable(fullfile(out,'calls.csv'),'TextType','string');
keys={'dataset','id','session','rep','budget'};measure=["total","first"];
counts=cell(0,16); details={}; observations={};
rng(40121,'twister');
for m=["cross","within","geom","geom_within"]
    a=T(T.method=="old_"+m,:);b=T(T.method=="fast_"+m,:);
    a=sortrows(a,keys);b=sortrows(b,keys);
    assert(height(a)==216 && isequal(a(:,keys),b(:,keys)) && isequal(a.status,b.status) && ...
        isequal(a.reason,b.reason) && isequal(a.trace_sha,b.trace_sha) && isequaln(a.rings,b.rings))
    for metric=measure
        if metric=="total",old=a.return_ms;fast=b.return_ms;else,old=a.first_ms;fast=b.first_ms;end
        reason=repmat("eligible",height(a),1);
        reason(a.status~="success")="no_legal_file";
        reason(a.status=="success" & ~logical(a.nonempty))="empty_input";
        reason(reason=="eligible" & (~isfinite(old) | ~isfinite(fast)))="unavailable_clock";
        reason(reason=="eligible" & (old<=0 | fast<=0))="nonpositive_clock";
        reason(reason=="eligible" & (old<0.0001 | fast<0.0001))="below_clock_resolution";
        include=reason=="eligible";logRatio=nan(size(old));logRatio(include)=log(fast(include)./old(include));
        d=a(:,[keys,{'rings','status','reason','nonempty'}]);d.method=repmat(m,height(a),1);d.metric=repmat(metric,height(a),1);
        d.old_ms=old;d.fast_ms=fast;d.log_ratio=logRatio;d.eligibility=reason;observations{end+1}=d;
        for scope=["all","single","multi"]
            use=include;
            if scope=="single",use=use & a.rings==1;elseif scope=="multi",use=use & a.rings>=2;end
            x=logRatio(use); sessions=NaN(1,3); ratio=NaN;ci=nan(1,4);ids=strings(0,1);
            if ~isempty(x)
                [g,id,sid]=findgroups(a.id(use),a.session(use));means=splitapply(@mean,x,g);
                for s=1:3,sessions(s)=exp(mean(means(sid==s)));end
                [g,ids]=findgroups(id);v=splitapply(@mean,means,g);ratio=exp(mean(v));
                draws=reshape(v(randi(numel(v),numel(v),10000)),numel(v),10000);
                ci=exp(prctile(mean(draws,1),[2.5 97.5 1.25 98.75]));
                details{end+1}=table(repmat(m,numel(v),1),repmat(metric,numel(v),1),repmat(scope,numel(v),1),ids,v,exp(v), ...
                    'VariableNames',{'method','metric','scope','id','mean_log_ratio','ratio'});
            end
            counts(end+1,:)={m,metric,scope,numel(ids),numel(x),ratio,sessions(1),sessions(2),sessions(3), ...
                ci(1),ci(2),ci(3),ci(4),nnz(~include),height(a),numel(unique(a.id))};
        end
    end
end
G=cell2table(counts,'VariableNames',{'method','metric','scope','n_sources','n_pairs','ratio','s1','s2','s3', ...
    'ci95_low','ci95_high','ci975_low','ci975_high','excluded_pairs_all','scheduled_pairs','scheduled_sources'});
writetable(G,fullfile(out,'gate.csv'));writetable(vertcat(details{:}),fullfile(out,'source_speed.csv'));
writetable(vertcat(observations{:}),fullfile(out,'paired_runs.csv'));
main=G(G.scope=="all" & G.metric=="total" & G.method=="cross",:);
protect=G(G.scope=="all" & ~(G.metric=="total" & G.method=="cross"),:);
pass=main.ratio<=.90 && all([main.s1 main.s2 main.s3]<1) && all(protect.ratio<=1.05);
label='NO-GO'; if pass,label='GO';end
decision=struct('decision',label,'go',logical(pass),'cross_ratio',main.ratio,'process_ratios',[main.s1 main.s2 main.s3], ...
    'worst_protected_ratio',max(protect.ratio),'eligible_sources',main.n_sources,'eligible_pairs',main.n_pairs);
efDevReceipts(out,T);
writeJson(fullfile(out,'decision.json'),decision);disp(decision)
end

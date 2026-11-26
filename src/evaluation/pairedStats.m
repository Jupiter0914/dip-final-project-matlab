function [sources,summary,coverage,pairedCoverage,sessions,loo,cats] = pairedStats(obs,manifest)
%先在源和会话内平均共同成功重复，再等权平均该源的有效会话
rng(40121,'twister');
claims=["cross","within_full";"cross","seed";"cross","matlab_geom"; ...
    "cross","matlab_geom_within";"exact","cross";"within_full","matlab_geom_within"];
keys={'dataset','id','session','rep','budget','deadline'};
sourceCells={};sumCells={};coverCells={};pairCoverCells={};sessionCells={};looCells={};catCells={};
for domain=["Oxford","LEMS"]
    for b=[128 256 512]
        for d=[100 200]
            group=obs(obs.dataset==domain & obs.budget==b & obs.deadline==d,:);
            for method=unique(group.method).'
                a=group(group.method==method,:);
                [g,~]=findgroups(a.id);
                rates=splitapply(@mean,double(a.status=="success"),g);
                coverCells(end+1,:)={domain,b,d,method,numel(rates),mean(rates), ...
                    nnz(rates>0),nnz(rates==1)};
            end
            for k=1:size(claims,1)
                method=claims(k,1);baseline=claims(k,2);
                a=group(group.method==method,:);z=group(group.method==baseline,:);
                if isempty(a)||isempty(z),continue;end
                pair=innerjoin(a,z,'Keys',keys,'LeftVariables',[keys,{'status','nbytes','xor','fp','fn','iou','rmse','rings'}], ...
                    'RightVariables',{'status','nbytes','xor','fp','fn','iou','rmse'});
                %通过列次序建立明确的左右名称，避免依赖表变量的自动后缀
                pair.Properties.VariableNames=[keys,{'sa','la','xa','fa','na','ia','ra','rings','sb','lb','xb','fb','nb','ib','rb'}];
                aa=pair.sa=="success";bb=pair.sb=="success";
                [g,~]=findgroups(pair.id);
                cd=splitapply(@mean,double(aa)-double(bb),g); ci=interval(cd);
                prefix={domain,b,d,method,baseline};
                pairCoverCells(end+1,:)=[prefix,{numel(cd),mean(cd),ci(1),ci(2),mean(aa & bb), ...
                    mean(aa & ~bb),mean(~aa & bb),mean(~aa & ~bb)}];
                joint=aa & bb & pair.la==pair.lb;
                p=pair(joint,:);
                if ~isempty(p)
                    p.delta=p.xb-p.xa; p.rel=p.delta./max(1,p.xb);
                    [g,id,sid]=findgroups(p.id,p.session);
                    calc=@(v)splitapply(@mean,v,g);
                    per=table(id,sid,calc(p.delta),calc(p.rel),calc(p.ia-p.ib), ...
                        calc(p.fb-p.fa),calc(p.nb-p.na),calc(p.rb-p.ra),calc(p.rings), ...
                        splitapply(@numel,p.delta,g),splitapply(@sum,double(p.xb==0),g), ...
                        'VariableNames',{'id','sid','gain','rel','iou','fp','fn','rmse','rings','n','zero'});
                    [g,ids]=findgroups(per.id);
                    v=table(ids,splitapply(@mean,per.gain,g),splitapply(@mean,per.rel,g), ...
                        splitapply(@mean,per.iou,g),splitapply(@mean,per.fp,g),splitapply(@mean,per.fn,g), ...
                        splitapply(@mean,per.rmse,g),splitapply(@max,per.rings,g),splitapply(@sum,per.n,g), ...
                        splitapply(@sum,per.zero,g),'VariableNames',{'id','gain','rel','iou','fp','fn','rmse','rings','n','zero'});
                    for n=1:height(v)
                        sourceCells(end+1,:)=[prefix,table2cell(v(n,:))];
                    end
                else
                    v=table(strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),'VariableNames',{'id','gain','rings','n'});
                    per=table(strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),'VariableNames',{'id','sid','gain','rings'});
                end
                for scope=["all","R1","R2+"]
                    use=scopeRows(v.rings,scope); x=v.gain(use); ci=interval(x);
                    full=v.gain(use & v.n==6); fullCI=interval(full);
                    sumCells(end+1,:)=[prefix,{scope,numel(x),sum(v.n(use)),mean(x),ci(1),ci(2), ...
                        median(x),nnz(x>0),nnz(x==0),nnz(x<0),numel(full),mean(full),fullCI(1),fullCI(2)}];
                    for sid=1:3
                        sv=per.gain(scopeRows(per.rings,scope) & per.sid==sid);
                        sc=interval(sv); sessionCells(end+1,:)=[prefix,{scope,sid,numel(sv),mean(sv),sc(1),sc(2)}];
                    end
                    ids=v.id(use);
                    for n=1:numel(x)
                        looCells(end+1,:)=[prefix,{scope,ids(n),(sum(x)-x(n))/(numel(x)-1)}];
                    end
                    if domain=="LEMS" && method=="cross" && baseline=="within_full" && ~isempty(x)
                        [tf,loc]=ismember(ids,manifest.id(manifest.dataset==domain)); assert(all(tf))
                        cat=manifest.category(manifest.dataset==domain);cat=cat(loc);
                        [g,names]=findgroups(cat); sums=splitapply(@sum,x,g); counts=splitapply(@numel,x,g);
                        picks=randi(numel(names),numel(names),10000);
                        draws=sum(reshape(sums(picks),size(picks)),1)./sum(reshape(counts(picks),size(picks)),1);
                        cc=prctile(draws,[2.5 97.5]);
                        for n=1:numel(names)
                            catCells(end+1,:)=[prefix,{scope,names(n),counts(n),sums(n)/counts(n), ...
                                mean(x(cat~=names(n))),cc(1),cc(2)}];
                        end
                    end
                end
            end
        end
    end
end
base={'dataset','budget','deadline','method','baseline'};
sources=asTable(sourceCells,[base,{'id','gain','relative_gain','iou_gain','fp_gain','fn_gain','rmse_gain','rings','n_pairs','zero_denominator'}]);
summary=asTable(sumCells,[base,{'scope','n_sources','n_pairs','mean_gain','ci_low','ci_high','median_gain','wins','ties','losses','n_complete','mean_complete','complete_low','complete_high'}]);
coverage=asTable(coverCells,{'dataset','budget','deadline','method','n_sources','rate','ever','always'});
pairedCoverage=asTable(pairCoverCells,[base,{'n_sources','rate_diff','ci_low','ci_high','both','only_method','only_baseline','neither'}]);
sessions=asTable(sessionCells,[base,{'scope','session','n_sources','mean_gain','ci_low','ci_high'}]);
loo=asTable(looCells,[base,{'scope','removed','mean_gain'}]);
cats=asTable(catCells,[base,{'scope','category','n','mean_gain','leave_category_out','cluster_low','cluster_high'}]);
end

function idx=scopeRows(r,scope)
idx=true(size(r));
if scope=="R1",idx=r==1;elseif scope=="R2+",idx=r>=2;end
end

function ci=interval(x)
if isempty(x),ci=[NaN NaN];return;end
n=numel(x); x=x(:);
draws=reshape(x(randi(n,n,10000)),n,10000);
ci=prctile(mean(draws,1),[2.5 97.5]);
end

function t=asTable(c,names)
if isempty(c),c=cell(0,numel(names));end
t=cell2table(c,'VariableNames',names);
end


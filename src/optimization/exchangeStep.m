function [next,log,audit]=exchangeStep(prep,state,method,diagnostic)
%一次只接受一个严格减少真实错分的联合操作，exact仅改变整对的筛选和排序
if nargin<4, diagnostic=false; end
assert(any(strcmp(method,{'within_full','cross','exact','matlab_geom_within','within_old','within_full_oldtri','cross_oldtri','cross_full_oldtri'})),'DIP:Method','Unknown exchange method')
isExact=strcmp(method,'exact');
allowCross=isExact || startsWith(method,'cross');
[pairs,eligible]=moveCandidates(prep,state,allowCross,method);
loss=zeros(numel(state.rings),1); whole=false(prep.shape);
for t=1:numel(loss)
    loss(t)=nnz(state.masks{t}~=prep.refs{t}); whole=xor(whole,state.masks{t});
end
base=sum(loss); total=size(pairs,1); next=state;
log=struct('accepted',false,'cross',false,'triangle',false,'donor',NaN,'donorVertex',NaN, ...
    'receiver',NaN,'receiverEdge',NaN,'removed',[],'inserted',[],'xorBefore',state.d, ...
    'xorAfter',state.d,'additiveBefore',base,'additiveAfter',base,'eligiblePairs',eligible, ...
    'proposedPairs',total,'fullChecks',0,'structuralRejects',0);
scores=inf(total,1); additions=nan(total,1); full=nan(total,1); legal=false(total,1);
trials=cell(total,1); audit=[];
for i=1:total
    m=pairs(i,:); dr=m(2); rr=m(4);
    cand=replaceVertex(state.rings,dr,m(3),rr,m(5),m(6:7));
    added=base; predicted=whole;
    for ring=unique([dr,rr])
        layer=rasterRing(prep.shape,cand{ring});
        if ~isExact || diagnostic
            added=added+nnz(layer~=prep.refs{ring})-loss(ring);
        end
        if isExact || diagnostic
            predicted=xor(xor(predicted,state.masks{ring}),layer);
        end
    end
    if ~isExact || diagnostic, additions(i)=added; end
    if isExact || diagnostic, full(i)=nnz(predicted~=prep.raw); end
    if diagnostic && full(i)<state.d
        [~,reason,d]=validateState(prep,cand);
        assert(d==full(i),'DIP:CachedRaster','Cached parity differs from full reconstruction')
        legal(i)=strcmp(reason,'ok');
    end
    if isExact
        if full(i)>=state.d, continue; end
        scores(i)=full(i);
    else
        if added>=base, continue; end
        scores(i)=added;
    end
    trials{i}=cand;
end
if diagnostic
    good=find(legal); screened=good(additions(good)<base);
    exactChoice=0; additiveChoice=0;
    if ~isempty(good), [~,j]=min(full(good)); exactChoice=good(j); end
    if ~isempty(screened), [~,j]=min(additions(screened)); additiveChoice=screened(j); end
    audit=struct('proposedPairs',total,'xorImproving',nnz(full<state.d), ...
        'skippedByAdd',nnz(full<state.d & additions>=base),'validSkippedByAdd',nnz(legal & additions>=base), ...
        'choicesDiffer',exactChoice~=additiveChoice,'exactChoice',exactChoice,'additiveChoice',additiveChoice, ...
        'moves',pairs,'additive',additions,'xor',full,'validImprovement',legal);
end
[~,rank]=sort(scores);
for i=rank(:)'
    if ~isfinite(scores(i)), break; end
    log.fullChecks=log.fullChecks+1;
    [candidate,reason,d]=validateState(prep,trials{i},state.d);
    if d>=state.d, continue; end
    if ~strcmp(reason,'ok')
        log.structuralRejects=log.structuralRejects+1; continue
    end
    m=pairs(i,:); dr=m(2); j=m(3); rr=m(4); next=candidate;
    log.accepted=true; log.cross=dr~=rr; log.triangle=state.allocation(dr)==3;
    log.donor=dr-1; log.donorVertex=j-1; log.receiver=rr-1; log.receiverEdge=m(5)-1;
    log.removed=state.rings{dr}(j,:); log.inserted=m(6:7);
    log.xorAfter=d; log.additiveAfter=additions(i);
    return
end
end

function [next,log,cache,trace]=efStep(prep,state,method,cache)
%前三个返回值用于生产，第四个返回值只在离线逐项核对时请求
if nargin<4,cache=[];end
assert(any(strcmp(method,{'within_full','cross','matlab_geom_within'})),'DIP:Method','Unknown exchange method')
tracing=nargout>3; allowCross=strcmp(method,'cross');
if tracing
    [pairs,eligible,loss,cache,trace]=efCandidates(prep,state,allowCross,cache);
else
    [pairs,eligible,loss,cache]=efCandidates(prep,state,allowCross,cache);
end
base=sum(loss); total=size(pairs,1); next=state;
log=struct('accepted',false,'cross',false,'triangle',false,'donor',NaN,'donorVertex',NaN, ...
    'receiver',NaN,'receiverEdge',NaN,'removed',[],'inserted',[],'xorBefore',state.d, ...
    'xorAfter',state.d,'additiveBefore',base,'additiveAfter',base,'eligiblePairs',eligible, ...
    'proposedPairs',total,'fullChecks',0,'structuralRejects',0);
scores=inf(total,1); trials=cell(total,1);
if tracing
    trace.pairs=pairs; trace.eligible=eligible; trace.baseAdditive=base; trace.lossByRing=loss;
    trace.additive=nan(total,1); trace.checked=zeros(0,1); trace.checkedXor=zeros(0,1);
    trace.checkedReason=strings(0,1);trace.invalidatedRings=zeros(0,1);
end
for i=1:total
    m=pairs(i,:); dr=m(2); rr=m(4);
    cand=replaceVertex(state.rings,dr,m(3),rr,m(5),m(6:7));
    %同圈须对联合后的完整折线算误差，单删和单插评分只用于提案排序
    added=base;
    for ring=unique([dr,rr])
        layer=rasterRing(prep.shape,cand{ring});
        added=added+nnz(layer~=prep.refs{ring})-loss(ring);
    end
    if tracing,trace.additive(i)=added;end
    if added>=base,continue;end
    scores(i)=added; trials{i}=cand;
end
[~,rank]=sort(scores); rank=rank(isfinite(scores(rank)));
if tracing,trace.rank=rank(:);end
for i=rank(:)'
    log.fullChecks=log.fullChecks+1;
    [candidate,reason,d]=validateState(prep,trials{i},state.d);
    if tracing
        trace.checked(end+1,1)=i;trace.checkedXor(end+1,1)=d;trace.checkedReason(end+1,1)=string(reason);
    end
    if d>=state.d,continue;end
    if ~strcmp(reason,'ok')
        log.structuralRejects=log.structuralRejects+1;continue
    end
    m=pairs(i,:);dr=m(2);j=m(3);rr=m(4); next=candidate;
    log.accepted=true;log.cross=dr~=rr;log.triangle=state.allocation(dr)==3;
    log.donor=dr-1;log.donorVertex=j-1;log.receiver=rr-1;log.receiverEdge=m(5)-1;
    log.removed=state.rings{dr}(j,:);log.inserted=m(6:7);
    log.xorAfter=d;log.additiveAfter=scores(i);
    %供受环的顶点顺序或数量发生变化，下一轮从原始稠密弧重算这些环
    cache.entry{dr}=[];cache.entry{rr}=[];
    if tracing,trace.invalidatedRings=unique([dr;rr]);end
    return
end
end

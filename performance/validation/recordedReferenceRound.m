function [next,log,trace]=recordedReferenceRound(prep,state,method,log)
%生产动作已由本轮同步事件独立保存，使用该动作验证新的参照计算
[d,r]=referenceSingles(prep,state);
[pairs,eligible]=refAllPairs(d,r,state.allocation,strcmp(method,'cross'));
[actual,actualEligible]=moveCandidates(prep,state,strcmp(method,'cross'),method);
assert(isequal(actual,pairs) && actualEligible==eligible && eligible==log.eligiblePairs);
n=size(pairs,1); added=zeros(n,1); whole=zeros(n,1);
vet=repmat("not_visited",n,1); topo=vet;
for i=1:n
    m=pairs(i,:); rings=replaceVertex(state.rings,m(2),m(3),m(4),m(5),m(6:7));
    predicted=false(prep.shape);
    for t=1:numel(rings)
        layer=rasterRing(prep.shape,rings{t});
        added(i)=added(i)+nnz(layer~=prep.refs{t});predicted=xor(predicted,layer);
    end
    whole(i)=nnz(predicted~=prep.raw);
end
order=find(added<log.additiveBefore);
[~,s]=sortrows([added(order),order],[1 2]);order=order(s);
tested=zeros(0,1);reasons=strings(0,1);next=state; won=false;
for i=order(:)'
    tested(end+1,1)=i;
    if whole(i)>=state.d
        reasons(end+1,1)="no_strict_xor_improvement"; continue
    end
    m=pairs(i,:);rings=replaceVertex(state.rings,m(2),m(3),m(4),m(5),m(6:7));
    [candidate,reason,dtrue]=validateState(prep,rings,state.d); assert(dtrue==whole(i));
    reasons(end+1,1)=string(reason); vet(i)=string(vectorCheck(rings,prep.parents));
    if vet(i)=="ok",topo(i)=string(reason);end
    if strcmp(reason,'ok')
        assert(log.accepted && log.donor+1==m(2) && log.donorVertex+1==m(3) && log.receiver+1==m(4) ...
            && log.receiverEdge+1==m(5) && isequal(log.inserted,m(6:7)) && log.xorAfter==dtrue);
        next=candidate;won=true;break
    end
end
assert(numel(tested)==log.fullChecks && won==log.accepted);
trace=struct('donors',d,'receivers',r,'pairs',pairs,'eligible',eligible,'additive',added,'xor',whole, ...
    'vector',vet,'digital',topo,'rank',order,'tested',tested,'reasons',reasons);
end

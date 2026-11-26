function [next,log,trace]=referenceRound(prep,state,method)
%由完整生产步骤给出真实动作，再独立重算所有单项和候选验收结果
[next,log,official]=exchangeStep(prep,state,method,true);
[d,r]=referenceSingles(prep,state);
[pairs,eligible]=refAllPairs(d,r,state.allocation,strcmp(method,'cross'));
assert(isequal(official.moves,pairs) && eligible==log.eligiblePairs,'EF:Reference','Reference top-24 differs from full enumeration')
n=size(pairs,1); added=zeros(n,1); whole=zeros(n,1); vector=strings(n,1); digital=strings(n,1);
for i=1:n
    m=pairs(i,:); rings=replaceVertex(state.rings,m(2),m(3),m(4),m(5),m(6:7));
    composed=false(prep.shape);
    for t=1:numel(rings)
        layer=rasterRing(prep.shape,rings{t});
        added(i)=added(i)+nnz(layer~=prep.refs{t}); composed=xor(composed,layer);
    end
    whole(i)=nnz(composed~=prep.raw);
    vector(i)=string(vectorCheck(rings,prep.parents));
    digital(i)=string(structureMatch(prep.reference,digitalLayout(composed)));
end
assert(isequaln(official.additive,added) && isequaln(official.xor,whole),'EF:Reference','Joint XOR or additive cost disagrees with complete repaint')
valid=whole<state.d & vector=="ok" & digital=="ok";
assert(isequal(official.validImprovement,valid),'EF:Reference','Candidate geometry or correspondence decision differs')
base=log.additiveBefore;
order=find(added<base);
[~,sorted]=sortrows([added(order),order],[1 2]); order=order(sorted);
take=find(valid(order),1);
tested=order;
if ~isempty(take), tested=order(1:take); end
assert(numel(tested)==log.fullChecks && ~isempty(take)==log.accepted,'EF:Reference','Accepted route differs from final ranking')
reasons=strings(numel(tested),1);
for j=1:numel(tested)
    i=tested(j);
    if whole(i)>=state.d, reasons(j)="no_strict_xor_improvement";
    elseif vector(i)~="ok", reasons(j)=vector(i); else, reasons(j)=digital(i); end
end
if log.accepted
    m=pairs(tested(end),:);
    assert(isequal(next.rings,replaceVertex(state.rings,m(2),m(3),m(4),m(5),m(6:7))) && next.d==whole(tested(end)));
end
trace=struct('donors',d,'receivers',r,'pairs',pairs,'eligible',eligible,'additive',added,'xor',whole, ...
    'vector',vector,'digital',digital,'rank',order,'tested',tested,'reasons',reasons);
end

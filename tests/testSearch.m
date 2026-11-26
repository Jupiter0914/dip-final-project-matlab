function tests=testSearch
tests=functiontests(localfunctions);
end

function setupOnce(test)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root,'src')));
test.TestData.root=root;
end

function testVectorAndRegionIdentity(test)
square=[1 1;21 1;21 21;1 21];
bad={[0 0;3 4;4 0;0 3],[0 0;2 0;1 0;2 2;0 2],[0 0;1 1;2 2]};
for k=1:numel(bad)
    verifyEqual(test,vectorCheck(bad(k),-1),'nonsimple_or_flat_ring')
end
verifyEqual(test,geometryTree({square;[2 2;19 2;19 19;2 19];[6 6;9 6;8 8]}),[-1;0;1])
verifyEqual(test,vectorCheck({square;square+20},[-1;-1]),'ring_boundaries_meet')
verifyEqual(test,vectorCheck({square;[3 3;8 3;7 9]},[-1;-1]),'nesting_changed')
a=false(20,30); a(2:5,2:7)=true; a(10:14,8:12)=true;
b=a; b(10:14,8:12)=false; b(12:16,18:22)=true;
verifyEqual(test,structureMatch(digitalLayout(a),digitalLayout(b)),'digital_overlap')
b=a; b(10:14,8:12)=false; b(14:18,12:16)=true;
verifyEqual(test,structureMatch(digitalLayout(a),digitalLayout(b)),'digital_overlap')
hole=~a; shifted=~b;
verifyEqual(test,structureMatch(digitalLayout(hole),digitalLayout(shifted)),'digital_overlap')
b=a; b(4:5,2:7)=false;
[reason,rows]=structureMatch(digitalLayout(a),digitalLayout(b));
verifyEqual(test,reason,'ok')
verifyTrue(test,any(rows(:,4)==24 & rows(:,5)==12 & rows(:,6)==12 & rows(:,7)==.5))
ref=digitalLayout(a); pred=ref; pred.adjacency(1,:)=[];
verifyEqual(test,structureMatch(ref,pred),'digital_adjacency')
end

function testDPAndAllocationPool(test)
m=90; angle=(0:m-1)'*2*pi/m; dense={round(100*[cos(angle),sin(angle)]);round(50*[cos(angle),sin(angle)])};
e=inf(1,m); e(3:end)=0; f=e;
[dp,per,pool,cost]=allocateCounts({e;f},dense,90);
verifyEqual(test,dp,[3 87])
verifySize(test,pool,[40 2]); verifyTrue(test,ismember(per,pool,'rows'))
verifyTrue(test,all(ismember([(3:22)',(87:-1:68)'],pool,'rows')))
verifyEqual(test,sum(pool,2),repmat(90,40,1)); verifyEqual(test,cost,zeros(40,1))
e=[Inf Inf 10 5 2 0]; f=[Inf Inf 7 3 2 0]; g=[Inf Inf 8 6 1 0];
[dp,~,pool,cost]=allocateCounts({e;f;g},[dense;dense(1)],14);
enumerated=zeros(0,4);
for a=3:6
    for b=3:6
        c=14-a-b;
        if c>=3 && c<=6, enumerated(end+1,:)=[e(a)+f(b)+g(c),a,b,c]; end
    end
end
enumerated=sortrows(enumerated);
verifyEqual(test,dp,enumerated(1,2:4)); verifyEqual(test,cost(1),enumerated(1,1))
verifyEqual(test,pool(1,:),dp)
end

function testTriangleReplacement(test)
mask=false(12,20); mask(3:10,3:18)=true; prep=prepareMask(mask,26);
[state,reason]=validateState(prep,{prep.dense{1}(1:3,:)});
assertEqual(test,reason,'ok')
[next,log]=exchangeStep(prep,state,'within_full');
verifyTrue(test,log.accepted && log.triangle && ~log.cross)
verifyEqual(test,[state.d,next.d],[126,56])
verifyEqual(test,numel(packPM31(prep.shape,next.rings,prep.parents)),26)
[more,legacy]=exchangeStep(prep,state,'within_full_oldtri');
verifyFalse(test,legacy.accepted); verifyEqual(test,more.rings,state.rings)
end

function testCandidateOrder(test)
mask=false(30,42); mask(4:14,3:17)=true; mask(8:13,13:17)=false; mask(18:25,22:38)=true;
prep=prepareMask(mask,46); n=[3 4]; rings=cell(2,1);
for r=1:2
    m=size(prep.dense{r},1); idx=floor((0:n(r)-1)*m/n(r))+1;
    rings{r}=prep.dense{r}(idx,:);
end
state=struct('rings',{rings},'allocation',n,'masks',{{rasterRing(prep.shape,rings{1}),rasterRing(prep.shape,rings{2})}});
for cross=[false true]
    [pairs,total]=moveCandidates(prep,state,cross);
    brute=brutePairs(prep,state,cross);
    verifyEqual(test,total,size(brute,1))
    verifyEqual(test,pairs,brute(1:min(24,end),:))
end
end

function rows=brutePairs(prep,state,cross)
%穷举合法对并统一排序，独立检查生产短表是否遗漏应入选的组合
rows=zeros(0,7);
for di=1:numel(state.rings)
    d=state.rings{di}; old=nnz(state.masks{di}~=prep.refs{di});
    for dj=1:size(d,1)
        cut=d; cut(dj,:)=[]; loss=nnz(rasterRing(prep.shape,cut)~=prep.refs{di})-old;
        for ri=1:numel(state.rings)
            if ri~=di && (~cross || size(d,1)<=3), continue; end
            q=state.rings{ri}; src=prep.dense{ri}; m=size(src,1);
            for j=1:size(q,1)
                nxt=mod(j,size(q,1))+1;
                if ri==di && any(dj==[j,nxt]), continue; end
                a=find(all(src==q(j,:),2)); b=find(all(src==q(nxt,:),2));
                len=mod(b-a-1,m);
                if ~len, continue; end
                arc=src(mod(a-1+(1:len),m)+1,:); chord=q(nxt,:)-q(j,:); off=arc-q(j,:);
                fraction=min(1,max(0,sum(off.*chord,2)/sum(chord.^2)));
                [~,far]=max(sum((off-fraction.*chord).^2,2));
                for k=unique([far,floor(len/2)+1])
                    ins=[q(1:j,:);arc(k,:);q(j+1:end,:)];
                    gain=nnz(rasterRing(prep.shape,ins)~=prep.refs{ri})-nnz(state.masks{ri}~=prep.refs{ri});
                    rows(end+1,:)=[loss+gain,di,dj,ri,j,arc(k,:)];
                end
            end
        end
    end
end
rows=sortrows(rows);
end

function testStatusesAndGeometry(test)
mask=false(24); mask(2:16,3:16)=true; mask(5:8,6:9)=false; mask(19:22,19:22)=true;
p=prepareMask(mask,12); verifyEqual(test,p.status,'below_proved_lower_bound')
p=prepareMask([1 2],128); verifyEqual(test,p.status,'unsupported_representation')
p=prepareMask(mask,128);
[s,i]=geometrySeed(p); assertEqual(test,i.status,'success');
verifyEqual(test,sum(s.allocation),p.target)
for k=1:numel(s.rings)
    verifyTrue(test,all(ismember(s.rings{k},p.dense{k},'rows')))
end
verifyEqual(test,vectorCheck(s.rings,p.parents),'ok')
verifyEqual(test,structureMatch(p.reference,digitalLayout(renderRings(p.shape,s.rings))),'ok')
[j,~]=geometrySeed(p); verifyEqual(test,j.rings,s.rings)
end

function testDevelopmentTransferReplay(test)
root=test.TestData.root;
manifest=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
row=manifest(manifest.id=="Maine_Coon_139",:); assertEqual(test,row.official,"trainval")
raw=readFrozenMask(root,row);
[within,ew]=measureEncoding(raw,256,'within_full',Inf,2);
[cross,ec]=measureEncoding(raw,256,'cross',Inf,2);
assertEqual(test,within.status,'success'); assertEqual(test,cross.status,'success')
assertEqual(test,ec(1).bytes,ew(1).bytes);
[~,w,parents]=decodePM31(ew(1).bytes); count=cellfun(@(p)size(p,1),w);
for i=1:numel(ew)
    [mask,rings]=decodePM31(ew(i).bytes); verifyEqual(test,nnz(xor(mask,raw)),ew(i).xor)
    verifyEqual(test,cellfun(@(p)size(p,1),rings),count)
end
assertTrue(test,any([ec.donor]~=[ec.receiver] & isfinite([ec.donor])))
for i=2:numel(ec)
    [before,old]=decodePM31(ec(i-1).bytes);
    [after,actual]=decodePM31(ec(i).bytes);
    log=cross.rounds{i-1};
    replay=replaceVertex(old,log.donor+1,log.donorVertex+1,log.receiver+1,log.receiverEdge+1,log.inserted);
    verifyEqual(test,replay,actual)
    verifyEqual(test,packPM31(size(raw),replay,parents),ec(i).bytes)
    verifyLessThan(test,nnz(after~=raw),nnz(before~=raw))
    verifyEqual(test,numel(ec(i).bytes),numel(ec(i-1).bytes))
    verifyEqual(test,vectorCheck(actual,parents),'ok')
    verifyEqual(test,structureMatch(digitalLayout(raw),digitalLayout(after)),'ok')
end
end

function testHistoricalDevSeed(test)
manifest=readtable(fullfile(test.TestData.root,'data','manifests','dev.csv'),'TextType','string');
row=manifest(manifest.id=="Bengal_148",:);
p=prepareMask(readFrozenMask(test.TestData.root,row),256); [s,i]=allocationSeed(p);
assertEqual(test,i.status,'success')
verifyEqual(test,s.d,121)
verifyEqual(test,sha256Bytes(packPM31(p.shape,s.rings,p.parents)),'56d0610e48db72b9410348ad89002b2a51cd9c9c66a4cce8d6a964747d8497b7')
[n,a,stats]=exchangeStep(p,s,'exact',true);
verifyEqual(test,stats.validSkippedByAdd,nnz(stats.validImprovement & stats.additive>=a.additiveBefore))
verifyTrue(test,all(stats.xor(stats.validImprovement)<s.d))
verifyLessThan(test,n.d,s.d)
end

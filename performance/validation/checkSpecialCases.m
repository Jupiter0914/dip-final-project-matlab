function S=checkSpecialCases(root,out)
%专门构造完整最优温和样例很少触发的边界分支
T=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
m=readFrozenMask(root,T(T.id=="american_pit_bull_terrier_15",:));
raw={true(1,16383),logical(eye(3)),m};
budgets=[256,10,128];expect=["unsupported_representation","below_proved_lower_bound","search_no_valid_output"];
for i=1:3
    row=validateTrajectory(raw{i},expect(i),budgets(i),"cross",out);
    assert(row{4}==expect(i),'EF:Fixture','Wrong terminal status for %s',expect(i));
end
m=false(12,20);m(3:10,3:18)=true;p=prepareMask(m,26);
[s,reason]=validateState(p,{p.dense{1}(1:3,:)});assert(strcmp(reason,'ok'));
[before,a,t]=referenceRound(p,s,'within_full');
[after,f,~,z]=efStep(p,s,'within_full',[]);
assert(a.accepted && a.triangle && ~a.cross && isequaln(a,f) && isequaln(before,after));
assert(isequaln(t.pairs,z.pairs) && isequaln(t.additive,z.additive) && isequaln(sortrows(z.donors),t.donors));
%两个环都往内移动，在翻转交集中两个变化必须抵消
shape=[20 25];outer=[4 4;88 4;88 72;4 72];hole=[8 8;72 8;72 60;8 60];
new1=outer+[20 0];new1(:,1)=min(new1(:,1),100);
new2=hole+[20 0];r0={outer;hole};r1={new1;new2};
a=renderRings(shape,r0);b=renderRings(shape,r1); ref=a;ref(1:4,1:9)=~ref(1:4,1:9);
f1=xor(rasterRing(shape,outer),rasterRing(shape,new1));f2=xor(rasterRing(shape,hole),rasterRing(shape,new2));
both=nnz(f1 & f2);assert(both>0 && ~isequal(f1|f2,xor(f1,f2)));
flip=xor(f1,f2);
assert(isequal(xor(a,flip),b) && nnz(ref~=a)+nnz(flip)-2*nnz(flip & (a~=ref))==nnz(ref~=b));
S=struct('unsupported',true,'below_lower_bound',true,'finite_pool_no_valid',true,'triangle_replacement',true,'cancelled_double_flips',both);
end

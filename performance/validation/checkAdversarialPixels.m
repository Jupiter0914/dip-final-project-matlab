function out=checkAdversarialPixels(folder)
%把诊断建立在真实生产的全局改边函数上，同时检查误差与每个翻转像素
edits=adversarialEdits(); evaluated=0; changed=0; triangle=0; fallback=0;
for i=1:numel(edits)
    e=edits(i);p=e.p; j=e.edge; a=rasterRing(e.shape,p);
    [yy,xx]=ndgrid(1:e.shape(1),1:e.shape(2));
    ref=mod(xx+2*yy,5)<2; base=nnz(a~=ref);
    del=p;del(j,:)=[]; ins=[p(1:j,:);e.insert;p(j+1:end,:)];
    b=rasterRing(e.shape,del);c=rasterRing(e.shape,ins);
    expected=[nnz(b~=ref)-base;nnz(c~=ref)-base];
    sets={find(xor(a,b));find(xor(a,c))};
    editsToCheck=[-1 j 0 0;1 j e.insert];
    try
        n=compareSingleChanges(e.shape,p,a,ref,editsToCheck,expected,sets);
    catch err
        if nargin>0
            witness=struct('id',e.id,'shape',e.shape,'points',p,'changes',editsToCheck,'gold_deltas',expected, ...
                'gold_flips',{sets},'identifier',err.identifier,'message',err.message);
            kernel=sha256Bytes(readBytes(which('efSingleChanges')));witness.kernel_sha256=kernel;
            prefix="adversarial_mismatch_"+string(kernel(1:12))+"_"+e.id;
            writeJson(fullfile(folder,prefix+".json"),witness);
            save(fullfile(folder,prefix+".mat"),'p','ref','a','b','c','sets','expected','editsToCheck');
        end
        fprintf('Adversarial case %s, H=%d W=%d, edge=%d\n',e.id,e.shape(1),e.shape(2),j);
        rethrow(err)
    end
    evaluated=evaluated+n(1);changed=changed+n(2);fallback=fallback+n(3);triangle=triangle+(size(p,1)==3);
end
%跨圈供点和受边同时翻转的像素需抵消，不能把两处局部面积直接相加
shape=[15 18];outer=[4 4;40 4;40 40;4 40];hole=[12 16;20 12;12 28];q=[32 14];
ra=rasterRing(shape,outer);rb=rasterRing(shape,hole);old=xor(ra,rb);
drop=outer([1 3 4],:);insert=[hole(1:2,:);q;hole(3,:)];
[~,fa]=efSingleChanges(shape,outer,ra,ra,[-1 2 0 0]);
[~,fb]=efSingleChanges(shape,hole,rb,rb,[1 2 q]);
overlap=numel(intersect(fa{1},fb{1}));assert(overlap>0,'EF:Fixture','Expected cancellation in overlap');
idx=setxor(fa{1},fb{1});actual=old; actual(idx)=~actual(idx);
truth=renderRings(shape,{drop;insert});assert(isequal(actual,truth));
out=struct('paths',numel(edits),'single_edits',evaluated,'checked_flip_pixels',changed,'triangle_two_point_paths',triangle, ...
    'double_flip_cancellations',overlap,'fallback_calls',fallback);
end

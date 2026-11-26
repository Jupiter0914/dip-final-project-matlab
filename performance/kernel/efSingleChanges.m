function [delta,flips,stats]=efSingleChanges(shape,p,current,reference,changes,captureFlips)
%每行描述一次独立删插，按原图线性索引合并奇偶翻转和边界命中
if nargin<6,captureFlips=nargout>1;end
n=size(changes,1); h=shape(1); w=shape(2); pixels=h*w;
delta=zeros(n,1); flips=cell(0,1);
if captureFlips,flips=cell(n,1);end
stats=struct('fallbackCalls',0,'baseLimitFallbacks',0,'editLimitFallbacks',0, ...
    'edgeBatches',0,'pixelBatches',0,'mode','global_discrete_edges');
if n==0,return;end
%限制临时事件表大小，超出的单个编辑改用原函数完整回填
edgeLimit=1000000; pixelLimit=500000;
if size(p,1)*max(shape)>edgeLimit
    for j=1:n
        [delta(j),ids]=direct(j);
        if captureFlips,flips{j}=ids;end
    end
    stats.baseLimitFallbacks=n;stats.fallbackCalls=n;return
end
p=double(p);q=p([2:end 1],:);
[row,cross,~,boundary,~]=edgeEvents(shape,p,q);
[~,rows,first,last]=parityIntervals(ones(size(row)),row,cross,w);
%中心左侧交点数的奇偶用开左闭右区间构成，恰落在交点的中心还计入边界
grid=sparse([rows;rows],[first;last+1],[ones(size(rows));-ones(size(rows))],h,w+1);
parity=cumsum(full(grid(:,1:w)),2)>0;
cover=groupSum(boundary,1,pixels);
assert(isequal(parity | reshape(cover>0,shape),current),'DIP:BaseRaster','Edge decomposition differs from current ring')
%避免单行画布按线性索引取值时保留原来的行方向
baseParity=parity(:); currentPixel=current(:); refPixel=reference(:);
maxEdits=max(1,floor(edgeLimit/(3*max(shape))));
for start=1:maxEdits:n
    stop=min(n,start+maxEdits-1); span=start:stop; k=numel(span);
    edit=changes(span,:); j=edit(:,2); op=edit(:,1);
    assert(all(op==-1 | op==1),'DIP:Edit','Unknown elementary operation')
    a=p(j,:); b=edit(:,3:4); c=p(mod(j,size(p,1))+1,:);
    cut=op==-1; a(cut,:)=p(mod(j(cut)-2,size(p,1))+1,:); b(cut,:)=p(j(cut),:);
    %插点时两条短边计入、原弦退出；删点时取相反符号
    [yr,xc,crossEdge,bc,bcEdge]=edgeEvents(shape,[a;b;a],[b;c;c]);
    owner=repmat((1:k)',3,1); signEdge=[op;op;-op];
    [unit,rr,lft,rgt]=parityIntervals(owner(crossEdge),yr,xc,w);
    bOwner=owner(bcEdge); bWeight=signEdge(bcEdge);
    demand=groupSum(unit,rgt-lft+1,k)+groupSum(bOwner,1,k);
    stats.edgeBatches=stats.edgeBatches+1;
    at=1;
    while at<=k
        if demand(at)>pixelLimit
            id=start+at-1; [delta(id),ids]=direct(id);
            if captureFlips,flips{id}=ids;end
            stats.editLimitFallbacks=stats.editLimitFallbacks+1;at=at+1;continue
        end
        take=at; total=demand(at);
        while take<k && total+demand(take+1)<=pixelLimit
            take=take+1;total=total+demand(take);
        end
        use=unit>=at & unit<=take; points=bOwner>=at & bOwner<=take;
        [which,col]=expand(lft(use),rgt(use));
        ry=rr(use); ed=unit(use);
        toggled=reshape(ry(which),[],1)+(col-1)*h+(reshape(ed(which),[],1)-at)*pixels;
        covered=reshape(bc(points),[],1)+(reshape(bOwner(points),[],1)-at)*pixels;
        [key,~,idx]=unique([toggled;covered]);
        if ~isempty(key)
            %同一位置原有多条边时，移走其中一条仍可能继续被覆盖
            hit=false(size(key));hit(idx(1:numel(toggled)))=true;
            signed=groupSum(idx(numel(toggled)+1:end),bWeight(points),numel(key));
            pix=mod(key-1,pixels)+1; whichEdit=floor((key-1)/pixels)+1;
            newCover=cover(pix)+signed;
            assert(all(newCover>=0),'DIP:EdgeCount','Negative boundary count')
            changed=(xor(baseParity(pix),hit) | newCover>0)~=currentPixel(pix);
            es=whichEdit(changed); changedPixels=pix(changed);
            increment=1-2*double(currentPixel(changedPixels)~=refPixel(changedPixels));
            delta(start+at-1:start+take-1)=groupSum(es,increment,take-at+1);
            if captureFlips
                for s=at:take
                    flips{start+s-1}=reshape(changedPixels(es==s-at+1),[],1);
                end
            end
        elseif captureFlips
            for s=at:take,flips{start+s-1}=zeros(0,1);end
        end
        stats.pixelBatches=stats.pixelBatches+1;at=take+1;
    end
end
stats.fallbackCalls=stats.editLimitFallbacks;
    function [d,ids]=direct(i)
        pos=changes(i,2); candidate=p;
        if changes(i,1)==-1
            candidate(pos,:)=[];
        else
            candidate=[p(1:pos,:);changes(i,3:4);p(pos+1:end,:)];
        end
        mask=rasterRing(shape,candidate);
        d=nnz(mask~=reference)-nnz(current~=reference);ids=[];
        if captureFlips,ids=find(mask~=current);ids=ids(:);end
    end
end

function [unit,row,first,last]=parityIntervals(edit,y,x,w)
%用严格小于像素中心的交点计数，每一对之间恰有一次奇偶翻转
z=sortrows([edit(:),y(:),x(:)],[1 2 3]); a=z(1:2:end,:); b=z(2:2:end,:);
assert(isequal(a(:,1:2),b(:,1:2)),'DIP:OddCrossings','Unpaired edit crossings')
first=max(1,floor(a(:,3)/262144)+1); last=min(w,floor(b(:,3)/262144));
keep=first<=last;unit=a(keep,1);row=a(keep,2);first=reshape(first(keep),[],1);last=reshape(last(keep),[],1);
end

function [row,cross,edge,boundary,bEdge]=edgeEvents(shape,p,q)
%每条有向边按原画布产生扫描交点和边线像素，允许多条边命中同一像素
h=shape(1);w=shape(2);lo=p;hi=q;reverse=p(:,2)>q(:,2);
lo(reverse,:)=q(reverse,:);hi(reverse,:)=p(reverse,:);
[edge,row]=expand(max(1,ceil(lo(:,2)/4)),min(h,ceil(hi(:,2)/4)-1));
slope=fix(65536*(hi(edge,1)-lo(edge,1))./(hi(edge,2)-lo(edge,2)));
cross=lo(edge,1)*65536+(4*row-lo(edge,2)).*slope;
through=mod(cross,262144)==0 & cross>=262144 & cross<=w*262144;
boundary=row(through)+(cross(through)/262144-1)*h;bEdge=edge(through);
%八连通线迹的主轴、方向和平分取整均与参考回填一致
a=p;b=q;reverse=p(:,1)>q(:,1);a(reverse,:)=q(reverse,:);b(reverse,:)=p(reverse,:);
d=b-a;steep=abs(d(:,2))>d(:,1);major=d(:,1);minor=d(:,2);origin=a(:,1);
major(steep)=d(steep,2);minor(steep)=d(steep,1);origin(steep)=a(steep,2);
first=mod(-sign(major).*origin,4);
[ix,step]=expand(zeros(size(first)),floor((abs(major)-first)/4));
len=first(ix)+4*step;den=max(1,abs(major(ix)));
shift=sign(minor(ix)).*floor((2*len.*abs(minor(ix))+den-1)./(2*den));
x=a(ix,1)+sign(major(ix)).*len; y=a(ix,2)+shift;
s=steep(ix);x(s)=a(ix(s),1)+shift(s);y(s)=a(ix(s),2)+sign(major(ix(s))).*len(s);
valid=mod(x,4)==0 & mod(y,4)==0 & x>=4 & x<=4*w & y>=4 & y<=4*h;
boundary=[boundary;y(valid)/4+(x(valid)/4-1)*h];bEdge=[bEdge;ix(valid)];
end

function [ix,value]=expand(first,last)
first=first(:);last=last(:);
if isempty(first),ix=zeros(0,1);value=zeros(0,1);return;end
counts=max(0,last-first+1); offset=cumsum(counts)-counts;
ix=reshape(repelem((1:numel(first))',counts),[],1);
value=(0:sum(counts)-1)'+reshape(first(ix)-offset(ix),[],1);
end


function v=groupSum(index,weight,n)
%全空的改边事件也产生规定长度的全零向量
if isempty(index),v=zeros(n,1);return;end
v=accumarray(index(:),weight(:),[n 1]);
end

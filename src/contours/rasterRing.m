function mask = rasterRing(shape,p)
%只求四倍画布中原像素中心的取值，坐标仍以扩展画布为准
h = shape(1);
w = shape(2);
mask = false(h,w);
if isempty(p)
    return
end
p = double(p);
q = p([2:end 1],:);
%原扫描线先从较小纵坐标出发，横向斜率截断到十六位小数
lo = p;
hi = q;
rev = p(:,2)>q(:,2);
lo(rev,:) = q(rev,:);
hi(rev,:) = p(rev,:);
first = max(1,ceil(lo(:,2)/4));
last = min(h,ceil(hi(:,2)/4)-1);
[count,rows] = expandRuns(first,last);
edge = repelem((1:size(p,1)).',count);
if ~isempty(rows)
    slope = fix(65536*(hi(edge,1)-lo(edge,1))./(hi(edge,2)-lo(edge,2)));
    cross = lo(edge,1)*65536+(4*rows-lo(edge,2)).*slope;
    hits = sortrows([rows,cross],[1 2]);
    assert(mod(size(hits,1),2)==0 && all(hits(1:2:end,1)==hits(2:2:end,1)),'DIP:OddCrossings','Unpaired scanline crossings')
    rr = hits(1:2:end,1);
    begin = max(1,ceil(hits(1:2:end,2)/(4*65536)));
    stop = min(w,floor(hits(2:2:end,2)/(4*65536)));
    keep = begin<=stop;
    rr = rr(keep);
    begin = begin(keep);
    stop = stop(keep);
    if ~isempty(rr)
        %相邻扫描区间以差分方式写入，端点像素包含在内
        top = min(rr);
        left = min(begin);
        tall = max(rr)-top+1;
        wide = max(stop)-left+1;
        delta = sparse([rr;rr]-top+1,[begin;stop+1]-left+1, ...
            [ones(size(rr));-ones(size(rr))],tall,wide+1);
        mask(top:top+tall-1,left:left+wide-1) = cumsum(full(delta(:,1:wide)),2)>0;
    end
end
%八连通边线总按从左到右的方向处理，恰好半格时保留较早一侧
a = p;
b = q;
flip = p(:,1)>q(:,1);
a(flip,:) = q(flip,:);
b(flip,:) = p(flip,:);
d = b-a;
steep = abs(d(:,2))>d(:,1);
major = d(:,1);
minor = d(:,2);
origin = a(:,1);
major(steep) = d(steep,2);
minor(steep) = d(steep,1);
origin(steep) = a(steep,2);
first = mod(-sign(major).*origin,4);
[count,step] = expandRuns(zeros(size(first)),floor((abs(major)-first)/4));
edge = repelem((1:size(p,1)).',count);
if isempty(edge)
    return
end
k = first(edge)+4*step;
den = max(1,abs(major(edge)));
shift = sign(minor(edge)).*floor((2*k.*abs(minor(edge))+den-1)./(2*den));
x = a(edge,1)+sign(major(edge)).*k;
y = a(edge,2)+shift;
v = steep(edge);
x(v) = a(edge(v),1)+shift(v);
y(v) = a(edge(v),2)+sign(major(edge(v))).*k(v);
valid = mod(x,4)==0 & mod(y,4)==0 & x>=4 & x<=4*w & y>=4 & y<=4*h;
mask(sub2ind([h w],y(valid)/4,x(valid)/4)) = true;
end

function [count,value] = expandRuns(first,last)
count = max(0,last-first+1);
offset = cumsum(count)-count;
value = (0:sum(count)-1).'+repelem(first-offset,count);
end

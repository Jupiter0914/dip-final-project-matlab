function [rings,parents] = extractRings(mask)
if ~supportedShape(size(mask)) || ~(islogical(mask) || isnumeric(mask)) || any(mask(:)~=0 & mask(:)~=1)
    error('DIP:Unsupported','Expected a supported two-dimensional binary mask')
end
[h,w] = size(mask);
v = false(h+2,w+2);
v(2:end-1,2:end-1) = mask;
%从左上开始顺时针把方格四角编码为低四位
tl = v(1:end-1,1:end-1);
tr = v(1:end-1,2:end);
br = v(2:end,2:end);
bl = v(2:end,1:end-1);
code = uint8(tl)+2*uint8(tr)+4*uint8(br)+8*uint8(bl);
active = find(code>0 & code<15);
if isempty(active)
    rings = cell(0,1);
    parents = zeros(0,1);
    return
end
[r,c] = ind2sub(size(code),active);
x = 4*(c-1);
y = 4*(r-1);
stride = 4*w+5;
%边顺序为上右下左，插值点距零值端为四分之一格
top = x+1+2*double(tl(active))+stride*y;
right = x+4+stride*(y+1+2*double(tr(active)));
bottom = x+1+2*double(bl(active))+stride*(y+4);
left = x+stride*(y+1+2*double(tl(active)));
edge = [top,right,bottom,left];
%对角鞍点中心为二分之一，两个前景角在等值线内相连
from = [1 2 2 3 1 3 3 4 1 4 2 4 1 4];
to   = [4 1 4 2 2 1 4 3 3 1 3 2 2 1];
kind = double(code(active));
seq = (1:numel(active)).';
source = edge(sub2ind(size(edge),seq,reshape(from(kind),[],1)));
dest = edge(sub2ind(size(edge),seq,reshape(to(kind),[],1)));
extra = find(kind==5 | kind==10);
side = 3-(kind(extra)==10);
other = 4-(kind(extra)==10);
source = [source;edge(sub2ind(size(edge),extra,side))];
dest = [dest;edge(sub2ind(size(edge),extra,other))];
[linked,next] = ismember(dest,source);
if ~all(linked) || numel(unique(next))~=numel(next)
    error('DIP:Unsupported','Contour segments do not form disjoint closed walks')
end
seen = false(size(next));
path = zeros(numel(next),1);
rings = cell(0,1);
keys = zeros(0,5);
for j = 1:numel(next)
    if seen(j)
        continue
    end
    at = j;
    n = 0;
    while ~seen(at)
        seen(at) = true;
        n = n+1;
        path(n) = source(at);
        at = next(at);
    end
    ids = path(1:n);
    p = [mod(ids,stride),floor(ids/stride)];
    q = p([2:end 1],:);
    twiceArea = sum(p(:,1).*q(:,2)-q(:,1).*p(:,2));
    %对齐原逐行扫描产生的起点，再删除共线点
    [~,anchor] = min(ids);
    if twiceArea>0
        anchor = mod(anchor-2,n)+1;
    end
    p = p([anchor:end 1:anchor-1],:);
    d1 = p-p([end 1:end-1],:);
    d2 = p([2:end 1],:)-p;
    p = p(d1(:,1).*d2(:,2)~=d1(:,2).*d2(:,1),:);
    if size(p,1)<3 || size(p,1)>65535 || numel(rings)>=32767
        error('DIP:Unsupported','Contour exceeds a PM31 field')
    end
    rings{end+1,1} = p;
    keys(end+1,:) = [-abs(twiceArea),min(p,[],1),max(p,[],1)];
end
[~,order] = sortrows(keys);
rings = rings(order);
parents = geometryTree(rings);
end

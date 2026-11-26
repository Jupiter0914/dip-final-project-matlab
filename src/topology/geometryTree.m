function parents = geometryTree(rings)
%先检查每条闭折线，再取所有包含环中面积最小的一个作为直接父环
n = numel(rings);
parents = -ones(n,1);
boxes = zeros(n,4);
areas = zeros(n,1);
for r = 1:n
    p = double(rings{r});
    if size(p,2)~=2 || size(p,1)<3 || any(~isfinite(p),'all')
        error('DIP:InvalidGeometry','nonsimple_or_flat_ring')
    end
    q = p([2:end 1],:);
    v = q-p;
    u = v([end 1:end-1],:);
    area = abs(sum(p(:,1).*q(:,2)-p(:,2).*q(:,1)));
    if area==0 || any(all(v==0,2)) || any(u(:,1).*v(:,2)==u(:,2).*v(:,1) & sum(u.*v,2)<0) || boundariesMeet(p,p,true)
        error('DIP:InvalidGeometry','nonsimple_or_flat_ring')
    end
    areas(r) = area;
    boxes(r,:) = [min(p,[],1) max(p,[],1)];
end
for i = 1:n
    for j = i+1:n
        if any(boxes(i,3:4)<boxes(j,1:2)) || any(boxes(j,3:4)<boxes(i,1:2))
            continue
        end
        if boundariesMeet(rings{i},rings{j},false)
            error('DIP:InvalidGeometry','ring_boundaries_meet')
        end
        if areas(i)>areas(j)
            outer=i; inner=j;
        else
            outer=j; inner=i;
        end
        if any(boxes(inner,1:2)<boxes(outer,1:2)) || any(boxes(inner,3:4)>boxes(outer,3:4))
            continue
        end
        p = rings{inner}(1,:); hull = rings{outer};
        if inpolygon(p(1),p(2),hull(:,1),hull(:,2))
            old = parents(inner)+1;
            if old==0 || areas(outer)<areas(old)
                parents(inner) = outer-1;
            end
        end
    end
end
end

function yes = boundariesMeet(p,q,self)
%整数行列式判定相交，先用包围盒筛掉不可能相交的线段
a = double(p); b = a([2:end 1],:);
c = double(q); d = c([2:end 1],:);
xmin=min(a(:,1),b(:,1)); xmax=max(a(:,1),b(:,1));
ymin=min(a(:,2),b(:,2)); ymax=max(a(:,2),b(:,2));
left=min(c(:,1),d(:,1))'; right=max(c(:,1),d(:,1))';
low=min(c(:,2),d(:,2))'; high=max(c(:,2),d(:,2))';
n = size(a,1); m = size(c,1);
yes = false;
if self && n<=3
    return
end
block = max(1,min(n,floor(262144/m)));
for start=1:block:n
    ii = (start:min(n,start+block-1))';
    active = xmin(ii)<=right & xmax(ii)>=left & ymin(ii)<=high & ymax(ii)>=low;
    if self
        active = active & (1:m)>ii+1 & ~(ii==1 & (1:m)==n);
    end
    [i,j] = find(active);
    if isempty(i)
        continue
    end
    i=ii(i); u=b(i,:)-a(i,:); v=d(j,:)-c(j,:);
    e=c(j,:)-a(i,:); f=d(j,:)-a(i,:); g=b(i,:)-c(j,:);
    s1=sign(u(:,1).*e(:,2)-u(:,2).*e(:,1));
    s2=sign(u(:,1).*f(:,2)-u(:,2).*f(:,1));
    s3=sign(v(:,2).*e(:,1)-v(:,1).*e(:,2));
    s4=sign(v(:,1).*g(:,2)-v(:,2).*g(:,1));
    if any(s1.*s2<=0 & s3.*s4<=0)
        yes=true;
        return
    end
end
end

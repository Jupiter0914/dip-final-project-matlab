function [state,info]=geometrySeed(prep)
%以原弧段到新弦的最大平方距离决定删点优先级，平局按原环和源顶点下标处理
state=[]; info=struct('status',prep.status,'reason',prep.reason,'removed',0,'blocked',0,'nativeRings',{{}});
if ~strcmp(prep.status,'success'), return; end
rings=prep.dense;
if isempty(rings)
    [state,info.reason]=validateState(prep,rings); return
end
k=cellfun(@(p)size(p,1),rings); n=sum(k); total=n;
p=vertcat(rings{:}); x=p(:,1); y=p(:,2);
ids=(1:n)'; before=ids-1; after=ids+1; first=cumsum(k)-k+1; last=cumsum(k);
before(first)=last; after(last)=first;
owner=repelem((1:numel(k))',k(:)); live=true(n,1);
cost=localCost(x(before),y(before),x,y,x(after),y(after));
cost(k(owner)<=3)=Inf;
%被某个活动顶点挡住的删除在该顶点移走后重新参加排序
waitFor=zeros(n,1);
while total>prep.target
    [value,j]=min(cost);
    if ~isfinite(value)
        info.status='search_no_valid_output'; info.reason='geometry_stopped_above_target';
        break
    end
    a=before(j); b=after(j); t=owner(j);
    possible=live & x>=min([x(a),x(j),x(b)]) & x<=max([x(a),x(j),x(b)]) ...
                  & y>=min([y(a),y(j),y(b)]) & y<=max([y(a),y(j),y(b)]);
    possible([a j b])=false;
    candidates=find(possible);
    if ~isempty(candidates)
        xx=x(candidates); yy=y(candidates);
        s1=(x(j)-x(a))*(yy-y(a))-(y(j)-y(a))*(xx-x(a));
        s2=(x(b)-x(j))*(yy-y(j))-(y(b)-y(j))*(xx-x(j));
        s3=(x(a)-x(b))*(yy-y(b))-(y(a)-y(b))*(xx-x(b));
        inside=(s1>=0 & s2>=0 & s3>=0) | (s1<=0 & s2<=0 & s3<=0);
        blocker=find(inside,1);
        if ~isempty(blocker)
            waitFor(j)=candidates(blocker); cost(j)=Inf;
            info.blocked=info.blocked+1; continue
        end
    end
    live(j)=false; cost(j)=Inf; before(b)=a; after(a)=b; k(t)=k(t)-1;
    total=total-1; info.removed=info.removed+1;
    affected=unique([a;b;find(waitFor==j)]);
    for h=affected(:)'
        waitFor(h)=0; u=owner(h);
        if ~live(h) || k(u)<=3
            cost(h)=Inf; continue
        end
        left=before(h); right=after(h);
        if left<right
            arc=left+1:right-1;
        else
            arc=[left+1:last(u),first(u):right-1];
        end
        %包含此前删去的所有原始弧点，不能只计算当前待删点到弦的距离
        cost(h)=max(localCost(x(left),y(left),x(arc),y(arc),x(right),y(right)));
    end
    if k(t)==3
        cost(first(t)-1+find(live(first(t):last(t))))=Inf;
    end
end
for t=1:numel(rings)
    rows=first(t):last(t); rings{t}=p(rows(live(rows)),:);
end
info.nativeRings=rings;
if total>prep.target, return; end
[state,info.reason]=validateState(prep,rings);
if ~strcmp(info.reason,'ok'), info.status='search_no_valid_output'; end
end

function d=localCost(xa,ya,xx,yy,xb,yb)
u=xb-xa; v=yb-ya; dx=xx-xa; dy=yy-ya;
f=min(1,max(0,(dx.*u+dy.*v)./max(1,u.^2+v.^2)));
d=(dx-f.*u).^2+(dy-f.*v).^2;
end

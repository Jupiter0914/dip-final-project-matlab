function [ids,fallback]=pol1Start(p,k,method)
n=size(p,1); path=[p;p(1,:)];
if n<k, error('DIP:BadOutline','Too few outline samples'); end
[~,opposite]=max(sum((p-p(1,:)).^2,2));
ids=sort([1,opposite]);
for count=3:k
    closed=[ids,n+1];
    best=-1; selected=0;
    for i=1:numel(ids)
        a=closed(i); b=closed(i+1);
        if b-a<2, continue; end
        delta=path(a+1:b-1,:)-path(a,:); chord=path(b,:)-path(a,:);
        t=min(1,max(0,(delta*chord')/max(1,chord*chord')));
        [err,j]=max(sum((delta-t.*chord).^2,2));
        if err>best, best=err; selected=a+j; end
    end
    ids=sort([ids,selected]);
end
rdp=ids; fallback=0;
if method~="rdp"
    if method=="full_dp"
        grid=1:n+1;
    else
        grid=unique([rdp,floor(linspace(0,n,min(n,8*k)+1))+1]);
    end
    %前缀矩允许在候选图上常数时间计算直线的平方误差
    x=p(:,1); y=p(:,2);
    prefix=[zeros(1,6);cumsum([ones(n,1),x,y,x.^2,x.*y,y.^2])];
    prefix=prefix(grid,:); verts=path(grid,:); m=numel(grid);
    cost=inf(m);
    for a=1:m-1
        b=(a+1:m)'; delta=verts(b,:)-verts(a,:);
        nx=-delta(:,2); ny=delta(:,1); z=-nx*verts(a,1)-ny*verts(a,2);
        sumSq=sum((prefix(b,:)-prefix(a,:)).*[z.^2,2*z.*nx,2*z.*ny,nx.^2,2*nx.*ny,ny.^2],2);
        denom=sum(delta.^2,2);
        se=max(0,sumSq)./max(1,denom); se(denom==0)=inf;
        cost(a,b)=se;
    end
    dist=inf(m,1); dist(1)=0; back=zeros(k,m);
    for j=1:k
        [best,back(j,:)]=min(cost+dist,[],1);
        dist=best';
    end
    last=m; ids=zeros(1,k);
    for j=k:-1:1
        last=back(j,last); ids(j)=grid(last);
    end
end
if ~strcmp(vectorCheck({p(ids,:)},-1),'ok')
    fallback=1; ids=rdp;
end
if ~strcmp(vectorCheck({p(ids,:)},-1),'ok')
    %出现自交时从三角形重建，每次仅加入不产生交叉的源点
    fallback=2;
    if k==3, error('DIP:BadOutline','No legal starting triangle'); end
    ids=pol1Start(p,3,"rdp");
    while numel(ids)<k
        test=[ids,n+1]; scores=zeros(0,2);
        for j=1:numel(ids)
            arc=(test(j)+1:test(j+1)-1)';
            if isempty(arc), continue; end
            d=path(arc,:)-path(test(j),:); v=path(test(j+1),:)-path(test(j),:);
            t=min(1,max(0,d*v'/max(1,v*v')));
            scores=[scores;[-sum((d-t.*v).^2,2),arc]];
        end
        scores=sortrows(scores,[1 2]); found=false;
        for i=1:size(scores,1)
            trial=sort([ids,scores(i,2)]);
            if strcmp(vectorCheck({p(trial,:)},-1),'ok'), ids=trial; found=true; break; end
        end
        if ~found, error('DIP:BadOutline','No admissible insertion'); end
    end
end
end

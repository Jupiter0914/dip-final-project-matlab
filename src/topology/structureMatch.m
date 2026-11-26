function [reason,rows] = structureMatch(ref,pred)
%输出列依次是区域类型、原编号、重建编号、原面积、重建面积、交集、召回率、精确率、面积比和局部交并比
rows=zeros(0,10);
if ref.nf~=pred.nf || ref.nh~=pred.nh
    reason='digital_counts';
    return
end
[fm,fg,ok1]=match(ref.fg,pred.fg,ref.fgAreas,pred.fgAreas,1,1,nargout>1);
[hm,bg,ok2]=match(ref.bg,pred.bg,ref.bgAreas,pred.bgAreas,2,2,nargout>1);
if ~ok1 || ~ok2
    reason='digital_overlap';
    return
end
hm(1)=1;
edges=ref.adjacency;
if ~isempty(edges)
    edges=sortrows([fm(edges(:,1)),hm(edges(:,2))]);
end
if ~isequal(edges,pred.adjacency)
    reason='digital_adjacency';
    return
end
reason='ok'; rows=[fg;bg];
end

function [mapping,rows,ok]=match(a,b,areas,outAreas,first,kind,details)
n=numel(areas);
mapping=zeros(n,1); rows=zeros(0,10); ok=true;
if n<first
    return
end
%只统计双方都有相应身份的像素，分母始终用两个完整区域的面积
hit=a>=first & b>=first;
counts=sparse(double(a(hit)),double(b(hit)),1,n,n);
[i,j,x]=find(counts);
if numel(i)~=n-first+1 || numel(unique(i))~=numel(i) || numel(unique(j))~=numel(j) || any(2*x<min(areas(i),outAreas(j)))
    ok=false; return
end
mapping(i)=j;
if details
    rows=sortrows([repmat(kind,numel(i),1),i,j,areas(i),outAreas(j),x,x./areas(i),x./outAreas(j),outAreas(j)./areas(i),x./(areas(i)+outAreas(j)-x)],2);
end
end

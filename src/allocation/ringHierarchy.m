function levels=ringHierarchy(points,limit)
%闭环先选一对远点，再优先分裂误差最大的弧段，平局按弧段起止下标处理
n=size(points,1); limit=min(n,limit);
levels=cell(1,limit);
[~,first]=max(sum((points-points(1,:)).^2,2));
p=points([first:n,1:first-1],:);
path=[p;p(1,:)];
[~,opposite]=max(sum((path-path(1,:)).^2,2));
ids=[1,opposite];
queue=[split(path,1,opposite);split(path,opposite,n+1)];
for k=3:limit
    [~,rank]=sortrows(queue,[1 2 3 4]);
    job=queue(rank(1),:); queue(rank(1),:)=[];
    begin=job(2); finish=job(3); middle=job(4);
    ids(end+1)=middle;
    levels{k}=p(sort(ids),:);
    queue=[queue;split(path,begin,middle);split(path,middle,finish)];
end
end

function job=split(p,i,j)
job=zeros(0,4);
if j-i<2
    return
end
v=p(j,:)-p(i,:); offsets=p(i+1:j-1,:)-p(i,:);
t=max(0,min(1,(offsets(:,1)*v(1)+offsets(:,2)*v(2))/max(1,sum(v.^2))));
d=sum((offsets-t.*v).^2,2);
[value,index]=max(d);
job=[-value,i,j,i+index];
end

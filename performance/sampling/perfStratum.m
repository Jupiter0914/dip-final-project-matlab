function [s,nf,nh,near]=perfStratum(raw)
%原分层比较不同数字边界的前景像素中心，圈间欧氏距离不超过三像素即为近邻
layout=digitalLayout(raw);nf=layout.nf;nh=layout.nh;
f=double(layout.fg);b=double(layout.bg);[r,c]=find(f>0);h=size(f,1);idx=sub2ind(size(f),r,c);
edges=cell(4,1);steps=[-1 1 -h h];
for k=1:4
    other=b(idx+steps(k));on=other>0;edges{k}=[f(idx(on)),other(on),idx(on)];
end
data=unique(vertcat(edges{:}),'rows');near=false;
if ~isempty(data)
    [g,pairs]=findgroups(data(:,1),data(:,2));
    if numel(pairs)>1
        radius=strel('disk',3,0);seen=false(size(f));
        for i=1:max(g)
            support=false(size(f));support(data(g==i,3))=true;
            if any(seen(support)),near=true;break;end
            seen=seen|imdilate(support,radius);
        end
    end
end
if near,s="near";elseif nh>0,s="holes";elseif nf>1,s="components";else,s="simple";end
end

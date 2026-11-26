function [target,points]=pol1Exterior(raw)
%只用于早期单圈实验，在原尺寸保留连续面积最大的外轮廓
loops=bwboundaries(raw,8,'noholes');
if isempty(loops)
    error('DIP:NoExterior','No foreground outline')
end
areas=cellfun(@(p) polyarea(p(:,2),p(:,1)),loops);
[~,id]=max(areas);
p=double(fliplr(loops{id}));
if isequal(p(1,:),p(end,:)), p(end,:)=[]; end
q=p([2:end 1],:);
if sum(p(:,1).*q(:,2)-q(:,1).*p(:,2))>0
    p=flipud(p);
end
%按原图的行扫描确定起点，用于解决等距时的先后顺序
[~,at]=min(p(:,2)*(size(raw,2)+1)+p(:,1));
p=p([at:end,1:at-1],:);
target=pol1Paint(size(raw),p);
[~,at]=max(sum((p-p(1,:)).^2,2));
points=p([at:end,1:at-1],:);
end

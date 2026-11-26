function [best,eligible]=refAllPairs(donors,receivers,counts,allowCross)
%诊断将所有合法组合排序，与生产中逐供点截取前二十四项的做法独立
lists=cell(size(donors,1),1);
for d=1:size(donors,1)
    cost=donors(d,1);r=donors(d,2);j=donors(d,3); prev=mod(j-2,counts(r))+1;
    same=receivers(:,2)==r;
    keep=(same & receivers(:,3)~=j & receivers(:,3)~=prev) | (~same & allowCross & counts(r)>3);
    recv=receivers(keep,:); n=size(recv,1);
    lists{d}=[recv(:,1)+cost,repmat([r j],n,1),recv(:,2:end)];
end
all=sortrows(vertcat(zeros(0,7),lists{:}));
eligible=size(all,1);best=all(1:min(24,eligible),:);
end

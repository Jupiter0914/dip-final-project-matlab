function schedule=efSchedule(rows,methods,stage,sid,rep)
%成对重复使用逆序，六个测量块再旋转起点，旧新两套在同源块内交错
names=string(methods); n=numel(names);groupN=height(rows);
sourceRank=strings(groupN,1); sequence=cell(groupN,1);
for i=1:groupN
    key="43129|"+stage+"|"+rows.dataset(i)+"/"+rows.id(i);
    sourceRank(i)=sha256Bytes(unicode2native(char(key+"|source|"+sid+"|"+rep),'UTF-8'));
    index=1:n;
    %相同机制的两个实现相邻，成对方法在首尾、先后位置上轮换
    if mod(n,2)==0
        pairs=reshape(index,2,[]).';
        hashes=strings(size(pairs,1),1);
        for k=1:size(pairs,1)
            hashes(k)=sha256Bytes(unicode2native(char(key+"|pair|"+k),'UTF-8'));
            if mod(i+k,2)==1,pairs(k,:)=fliplr(pairs(k,:));end
        end
        [~,ix]=sort(hashes);
        pairs=circshift(pairs(ix,:),-(sid-1),1);
        index=reshape(pairs.',1,[]);
    end
    if rep==2,index=fliplr(index);end
    sequence{i}=names(index);
end
[~,order]=sort(sourceRank);
schedule=table(order,sequence(order),'VariableNames',{'row','methods'});
end

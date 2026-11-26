function counts=checkRoundFlips(prep,state,trace)
%逐项恢复“当前有序环加一次编辑”的真掩模，不能用孤立误差差值推断翻转相同
counts=zeros(1,3);
for r=1:numel(state.rings)
    p=state.rings{r}; one=trace.donors(trace.donors(:,2)==r,:);
    two=trace.receivers(trace.receivers(:,2)==r,:);
    changes=[-ones(size(one,1),1),one(:,3),zeros(size(one,1),2);ones(size(two,1),1),two(:,3:5)];
    expected=[one(:,1);two(:,1)]; actual=state.masks{r}; ref=prep.refs{r};
    assert(isequal(actual,rasterRing(prep.shape,p)));
    truth=cell(size(changes,1),1);
    for j=1:size(changes,1)
        edge=changes(j,2); edited=p;
        if changes(j,1)==-1,edited(edge,:)=[];else,edited=[p(1:edge,:);changes(j,3:4);p(edge+1:end,:)];end
        after=rasterRing(prep.shape,edited);truth{j}=find(actual~=after);
        assert(expected(j)==nnz(after~=ref)-nnz(actual~=ref));
    end
    counts=counts+compareSingleChanges(prep.shape,p,actual,ref,changes,expected,truth);
end
end

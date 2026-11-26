function rings=replaceVertex(rings,donor,j,recipient,edge,xy)
%接口传入操作前的MATLAB下标，删点后修正同圈接收边的位置
n=size(rings{donor},1);
if donor==recipient && (j==edge || j==mod(edge,n)+1)
    error('DIP:InvalidMove','Receiving edge is incident to the deleted vertex')
end
if donor~=recipient && n<=3
    error('DIP:InvalidMove','Cross-ring donor would shrink below three vertices')
end
rings{donor}(j,:)=[];
if donor==recipient && j<edge, edge=edge-1; end
p=rings{recipient};
rings{recipient}=[p(1:edge,:);xy;p(edge+1:end,:)];
end

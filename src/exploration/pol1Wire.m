function [bytes,pred]=pol1Wire(shape,p)
if ~strcmp(vectorCheck({p},-1),'ok') || any(p<1 | p>fliplr(shape) | p~=fix(p),'all')
    error('DIP:BadPOL1','Invalid integer polygon')
end
fields=[shape(2),shape(1),size(p,1),reshape((p-1).',1,[])];
bytes=[uint8('POL1'),reshape(uint8([mod(fields,256);floor(fields/256)]),1,[])];
%从交付字节独立还原顶点，防止计分误用优化过程中的中间点
if nargout>1
    raw=bytes(5:end);
    values=double(raw(1:2:end))+256*double(raw(2:2:end));
    assert(values(3)*4+10==numel(bytes));
    pred=pol1Paint(values([2 1]),reshape(values(4:end),2,[])'+1);
end
end

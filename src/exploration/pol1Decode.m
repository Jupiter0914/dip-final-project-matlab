function [mask,p]=pol1Decode(bytes)
%从实际 POL1 文件单独取出原生整数点，再调用单圈画布
if ~isa(bytes,'uint8') || numel(bytes)<22 || ~isequal(bytes(1:4),uint8('POL1')) || mod(numel(bytes)-10,4)
    error('DIP:InvalidPOL1','Invalid POL1 header or byte length')
end
u=double(bytes(5:2:end))+256*double(bytes(6:2:end));
w=u(1); h=u(2); k=u(3);
if w==0 || h==0 || k<3 || numel(bytes)~=10+4*k
    error('DIP:InvalidPOL1','Invalid POL1 dimensions or count')
end
p=reshape(u(4:end),2,[])'+1;
if any(p>[w h],'all') || ~strcmp(vectorCheck({p},-1),'ok')
    error('DIP:InvalidPOL1','Invalid POL1 polygon')
end
mask=pol1Paint([h w],p);
end

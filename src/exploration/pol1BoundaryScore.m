function f=pol1BoundaryScore(target,pred,r)
%腐蚀时把图外当背景，距离容差采用欧氏圆盘
a=padarray(target,[1 1],false);
b=padarray(pred,[1 1],false);
a=a & ~imerode(a,true(3)); b=b & ~imerode(b,true(3));
a=a(2:end-1,2:end-1); b=b(2:end-1,2:end-1);
[x,y]=meshgrid(-r:r);
disk=x.^2+y.^2<=r^2;
hp=nnz(b & imdilate(a,disk));
hr=nnz(a & imdilate(b,disk));
f=2*hp*hr/max(1,hp*nnz(a)+hr*nnz(b));
end

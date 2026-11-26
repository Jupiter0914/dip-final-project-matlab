function mask=pol1Paint(shape,p)
%早期外轮廓保存像素中心，在原尺寸画布直接绘制整数八连通边
h=shape(1); w=shape(2);
q=p([2:end 1],:); a=p; b=q;
reverse=p(:,2)>q(:,2);
a(reverse,:)=q(reverse,:); b(reverse,:)=p(reverse,:);
num=b(:,2)-a(:,2);
ix=repelem((1:size(p,1))',num);
step=(0:sum(num)-1)'-repelem(cumsum(num)-num,num);
y=a(ix,2)+step;
x=a(ix,1)*65536+step.*fix((b(ix,1)-a(ix,1))*65536./num(ix));
hits=sortrows([y x]);
start=ceil(hits(1:2:end,2)/65536);
stop=floor(hits(2:2:end,2)/65536);
row=hits(1:2:end,1);
mask=logical(cumsum(full(sparse([row;row],[start;stop+1], ...
    [ones(size(row));-ones(size(row))],h,w+1)),2));
mask=mask(:,1:w);
a=p; b=q;
reverse=p(:,1)>q(:,1); a(reverse,:)=q(reverse,:); b(reverse,:)=p(reverse,:);
v=b-a; steep=abs(v(:,2))>v(:,1);
major=v(:,1); minor=v(:,2);
major(steep)=v(steep,2); minor(steep)=v(steep,1);
count=abs(major)+1;
ix=repelem((1:size(p,1))',count);
k=(0:sum(count)-1)'-repelem(cumsum(count)-count,count);
den=max(1,abs(major(ix)));
shift=sign(minor(ix)).*floor((2*k.*abs(minor(ix))+den-1)./(2*den));
x=a(ix,1)+sign(major(ix)).*k; y=a(ix,2)+shift;
s=steep(ix); x(s)=a(ix(s),1)+shift(s); y(s)=a(ix(s),2)+sign(major(ix(s))).*k(s);
mask(sub2ind([h w],y,x))=true;
end

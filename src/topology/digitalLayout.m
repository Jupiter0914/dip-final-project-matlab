function layout = digitalLayout(mask)
%补边让所有外背景连为同一区域，有限孔从标签二开始
[h,w]=size(mask);
p=false(h+2,w+2);
p(2:end-1,2:end-1)=mask;
fg=bwconncomp(p,8);
bg=bwconncomp(~p,4);
layout.fg=labelmatrix(fg);
layout.bg=labelmatrix(bg);
layout.nf=fg.NumObjects; layout.nh=bg.NumObjects-1;
layout.fgAreas=cellfun(@numel,fg.PixelIdxList(:));
layout.bgAreas=cellfun(@numel,bg.PixelIdxList(:));
assert(layout.bg(1,1)==1,'DIP:Exterior','Exterior label must be 1')
%只有共边的前背景像素产生邻接，角点不算一条邻接边
f=layout.fg; b=layout.bg;
pairs=[adjacent(f(1:end-1,:),b(2:end,:)); adjacent(f(2:end,:),b(1:end-1,:)); ...
       adjacent(f(:,1:end-1),b(:,2:end)); adjacent(f(:,2:end),b(:,1:end-1))];
layout.adjacency=unique(pairs,'rows');
end

function pairs = adjacent(f,b)
touch=f>0 & b>0;
x=double(f(touch)); y=double(b(touch));
pairs=[x(:),y(:)];
end

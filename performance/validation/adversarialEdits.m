function edits=adversarialEdits()
%扫描线与边线均以扩展画布整数为准，端点正落在采样线上时也保留
shape=[15 18];
p={ [4 4;40 4;40 40;4 40], ...
    [4 4;40 4;40 35;24 18;20 36;16 18;4 40], ...
    [4 12;19 4;36 20], ...
    [4 4;36 20;12 36], ...
    [4 6;36 22;19 39;3 18], ...
    [0 0;36 0;72 44;72 60;4 60], ...
    [3 4;38 8;39 12;52 20;39 13;36 12;3 32], ...
    [8 8;48 8;48 44;32 44;32 20;24 20;24 44;8 44]};
labels=["exact_center_intersections","multiple_even_crossings","triangle_forward_reverse", ...
    "positive_half_grid","negative_half_grid","canvas_border","overlapping_line8_samples","narrow_double_sweep"];
edits=struct('id',{},'shape',{},'p',{},'edge',{},'insert',{});
for i=1:numel(p)
    for reverse=[false true]
        pts=p{i};
        if reverse,pts=flipud(pts);end
        %不同边反向时，半格并列和端点命中需要独立核对
        for j=1:size(pts,1)
            next=mod(j,size(pts,1))+1;
            mid=round((pts(j,:)+pts(next,:))/2);
            q=min(4*(fliplr(shape)+1),max(0,mid+[2 -3]));
            edits(end+1)=struct('id',labels(i)+"-"+reverse+"-"+j,'shape',shape,'p',pts,'edge',j,'insert',q);
        end
    end
end
%长宽之一为一时，线性索引得到行或列的规则不同，两方向分别逐像素检查
shapes={[1 16],[16 1],[1 1],[3 32],[32 3]};
for i=1:numel(shapes)
    sh=shapes{i}; h=4*sh(1)+4; w=4*sh(2)+4;
    pts=[0 0;w 0;w h;0 h];
    if i<=3
        other=[0 4;min(w,4) 0;w min(h,4);min(w,4) h;0 min(h,6)];
        for j=1:size(other,1)
            next=mod(j,size(other,1))+1; q=round((other(j,:)+other(next,:))/2);
            edits(end+1)=struct('id',"one_axis_inner_"+i+"_"+j,'shape',sh,'p',other,'edge',j,'insert',q);
        end
    end
    for j=1:4
        q=min([w h],max(0,round((pts(j,:)+pts(mod(j,4)+1,:))/2)+[1 -2]));
        edits(end+1)=struct('id',"full_axis_border_"+i+"_"+j,'shape',sh,'p',pts,'edge',j,'insert',q);
    end
end
end

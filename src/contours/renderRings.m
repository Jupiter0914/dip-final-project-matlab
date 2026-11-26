function mask = renderRings(shape,rings)
%每个环单独绘制，嵌套孔和岛由奇偶关系决定
mask = false(shape);
for i = 1:numel(rings)
    mask = xor(mask,rasterRing(shape,rings{i}));
end
end

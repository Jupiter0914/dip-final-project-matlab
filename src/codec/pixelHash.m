function digest = pixelHash(mask)
%行优先连续位流，不在两行之间补齐字节
[h,w] = size(mask);
bits = uint8(reshape(mask.',[],1));
bits(end+1:end+mod(-numel(bits),8)) = 0;
packed = uint8([128 64 32 16 8 4 2 1] * double(reshape(bits,8,[])));
header = uint8(mod(floor([h;w]./(256.^(0:3))),256));
digest = sha256Bytes([reshape(header.',1,[]),packed]);
end

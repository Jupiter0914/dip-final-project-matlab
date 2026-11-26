function bytes = packPM31(shape,rings,parents)
if ~supportedShape(shape) || ~iscell(rings) || numel(rings)~=numel(parents) || numel(rings)>32767
    error('DIP:InvalidPM31','Invalid PM31 header')
end
counts = cellfun(@(p) size(p,1),rings);
if any(counts<3 | counts>65535)
    error('DIP:InvalidPM31','Invalid vertex count')
end
bytes = zeros(1,10+4*numel(rings)+4*sum(counts),'uint8');
bytes(1:4) = uint8('PM31');
bytes(5:10) = le16([shape(2),shape(1),numel(rings)]);
pos = 11;
for i = 1:numel(rings)
    p = double(rings{i});
    parent = double(parents(i));
    if size(p,2)~=2 || any(~isfinite(p) | p<0 | p~=fix(p) | p>4*(fliplr(shape(:).')+1),'all') ...
            || ~isscalar(parent) || ~isfinite(parent) || parent~=fix(parent) || parent < -1 || parent>=i-1
        error('DIP:InvalidPM31','Invalid ring coordinates or parent')
    end
    %父编号负一按有符号十六位的补码写入
    record = le16([mod(parent,65536),size(p,1),reshape(p.',1,[])]);
    bytes(pos:pos+numel(record)-1) = record;
    pos = pos+numel(record);
end
end

function b = le16(values)
values = double(values(:).');
b = reshape(uint8([mod(values,256);floor(values/256)]),1,[]);
end

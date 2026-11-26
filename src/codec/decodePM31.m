function [mask,rings,parents] = decodePM31(bytes)
if ~isa(bytes,'uint8') || ~isvector(bytes) || numel(bytes)<10
    error('DIP:InvalidPM31','Truncated or non-byte PM31 header')
end
bytes = bytes(:).';
if ~isequal(bytes(1:4),uint8('PM31'))
    error('DIP:InvalidPM31','Incorrect PM31 magic')
end
head = u16(bytes(5:10));
shape = head([2 1]);
n = head(3);
if ~supportedShape(shape) || n>32767 || numel(bytes)<10+16*n
    error('DIP:InvalidPM31','Invalid dimensions or truncated record')
end
rings = cell(n,1);
parents = zeros(n,1);
pos = 11;
for i = 1:n
    if pos+3>numel(bytes)
        error('DIP:InvalidPM31','Truncated ring header')
    end
    h = u16(bytes(pos:pos+3));
    parents(i) = h(1)-65536*(h(1)>=32768);
    k = h(2);
    pos = pos+4;
    if parents(i)<-1 || parents(i)>=i-1 || k<3 || pos+4*k-1>numel(bytes)
        error('DIP:InvalidPM31','Invalid parent or vertex count')
    end
    p = reshape(u16(bytes(pos:pos+4*k-1)),2,[]).';
    if any(p>4*(fliplr(shape)+1),'all')
        error('DIP:InvalidPM31','Coordinate outside the padded canvas')
    end
    rings{i} = p;
    pos = pos+4*k;
end
if pos~=numel(bytes)+1
    error('DIP:InvalidPM31','Unexpected trailing bytes')
end
reason = vectorCheck(rings,parents);
if ~strcmp(reason,'ok')
    error('DIP:InvalidPM31','Invalid vector geometry: %s',reason)
end
mask = renderRings(shape,rings);
end

function v = u16(b)
v = double(b(1:2:end))+256*double(b(2:2:end));
end

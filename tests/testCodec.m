function tests = testCodec
tests = functiontests(localfunctions);
end

function setupOnce(test)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root,'src')));
test.TestData.root = root;
test.TestData.compat = fullfile(root,'data','compat');
end

function testExhaustiveAndNamed(test)
gold = readtable(fullfile(test.TestData.compat,'analytic.csv'),'TextType','string');
for i = 1:height(gold)
    name = gold.id(i);
    if i<=512
        bits = logical(bitget(uint16(i-1),1:9));
        mask = reshape(bits,3,3).';
    else
        mask = namedMask(name);
    end
    [rings,parents] = extractRings(mask);
    bytes = packPM31(size(mask),rings,parents);
    actual = decodePM31(bytes);
    comparePixels(test,name,mask,actual);
    assertEqual(test,pixelHash(mask),char(gold.input_pixel_sha256(i)),char(name));
    assertEqual(test,sha256Bytes(bytes),char(gold.wire_sha256(i)),char(name));
    assertEqual(test,numel(bytes),10+4*numel(rings)+4*sum(cellfun(@(p) size(p,1),rings)));
end
end

function testHistoricalWire(test)
data = readtable(fullfile(test.TestData.compat,'legacy.csv'),'TextType','string');
assertEqual(test,height(data),12);
for i = 1:height(data)
    path = fullfile(test.TestData.compat,data.file(i));
    fid = fopen(path,'rb');
    guard = onCleanup(@() fclose(fid));
    bytes = fread(fid,Inf,'*uint8').';
    clear guard
    props = dir(path);
    assertEqual(test,props.bytes,numel(bytes));
    assertEqual(test,sha256Bytes(bytes),char(data.wire_sha256(i)));
    [actual,rings,parents] = decodePM31(bytes);
    truth = imread(replace(path,'.pm3','.png'))~=0;
    comparePixels(test,data.id(i)+"-"+data.budget(i),truth,actual);
    assertEqual(test,pixelHash(actual),char(data.decode_sha256(i)));
    assertEqual(test,packPM31(size(actual),rings,parents),bytes);
end
end

function testLineEightAndScanlines(test)
cases = jsondecode(fileread(fullfile(test.TestData.compat,'raster.json')));
for i = 1:numel(cases)
    c = cases(i);
    actual = rasterRing([c.h c.w],c.xy);
    bytes = uint8(hex2dec(reshape(c.row_bits,2,[]).'));
    bits = false(numel(bytes),8);
    for j=1:8
        bits(:,j) = bitget(bytes,9-j);
    end
    linear = reshape(bits.',[],1);
    expected = reshape(linear(1:c.h*c.w),c.w,c.h).';
    comparePixels(test,"raster-"+i,expected,actual);
    assertEqual(test,pixelHash(actual),c.pixel_sha256);
end
end

function testMalformedWire(test)
raw = packPM31([1 1],{[1 4;4 1;7 4;4 7]},-1);
mutants = {uint8([]),raw(1:9),[raw 0],raw(1:end-1)};
for offset = [1 5 9 11 13 15]
    trial = raw;
    if offset==1
        trial(offset)=0;
    elseif offset==5
        trial(offset:offset+1)=0;
    elseif offset==9
        trial(offset:offset+1)=255;
    elseif offset==11
        trial(offset:offset+1)=0;
    elseif offset==13
        trial(offset)=2;
    else
        trial(offset)=255;
    end
    mutants{end+1}=trial;
end
for i=1:numel(mutants)
    assertError(test,@() decodePM31(mutants{i}),'DIP:InvalidPM31');
end
bow = packPM31([4 4],{[2 2;12 12;2 12;12 2]},-1);
assertError(test,@() decodePM31(bow),'DIP:InvalidPM31');
assertError(test,@() extractRings(zeros(1,16383)),'DIP:Unsupported');
assertError(test,@() extractRings([0 2]),'DIP:Unsupported');
end

function testDevelopmentSources(test)
root = test.TestData.root;
manifest = readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
assertEqual(test,height(manifest),36);
gold = readtable(fullfile(test.TestData.compat,'dev_dense.csv'),'TextType','string');
assertEqual(test,manifest.id,gold.id);
for i = 1:height(manifest)
    row = manifest(i,:);
    assertEqual(test,row.official,"trainval");
    mask = readFrozenMask(root,row);
    [rings,parents] = extractRings(mask);
    bytes = packPM31(size(mask),rings,parents);
    comparePixels(test,row.id,mask,decodePM31(bytes));
    assertEqual(test,sha256Bytes(bytes),char(gold.wire_sha256(i)),char(row.id));
end
end

function comparePixels(test,id,expected,got)
%出现差异时在开发证据目录同时保存参考、实际和异或图
if ~isequal(expected,got)
    folder = fullfile(test.TestData.root,'results','failures','codec',string(id));
    if ~isfolder(folder)
        mkdir(folder);
    end
    imwrite(expected,fullfile(folder,'reference.png'));
    imwrite(got,fullfile(folder,'matlab.png'));
    imwrite(xor(expected,got),fullfile(folder,'difference.png'));
end
assertEqual(test,got,expected,char(id));
end

function a = namedMask(name)
a = false(13,14);
switch name
    case "empty"
    case "full"
        a(:)=true;
    case "one_border_pixel"
        a(1,1)=true;
    case "corner_touch"
        a(7,8)=true; a(8,9)=true;
    case "one_pixel_hole"
        a(2:12,2:13)=true; a(6,7)=false;
    case "island_in_hole"
        a(2:end-1,2:end-1)=true;
        a(4:end-3,4:end-3)=false;
        a(6:end-5,6:end-5)=true;
    case "diagonal_neck"
        a(2:5,2:5)=true;
        a(9:12,10:13)=true;
        a(sub2ind(size(a),5:9,6:10))=true;
    case "near_components"
        a(3:11,2:6)=true; a(3:11,9:13)=true;
    otherwise
        error('DIP:UnknownCase','Unrecognized analytic case')
end
end

function mask = readFrozenMask(root,row)
%清单中的路径相对于项目根目录
path = fullfile(root,string(row.file));
fid = fopen(path,'rb');
if fid < 0
    error('DIP:SourceMissing','Missing input %s',path)
end
guard = onCleanup(@() fclose(fid));
raw = fread(fid,Inf,'*uint8');
if ~strcmp(sha256Bytes(raw),string(row.raw_sha256))
    error('DIP:RawHash','Source byte hash differs for %s',string(row.id))
end
clear guard
%索引图直接读取调色板编号，不能换成显示灰度
v = imread(path);
if ~ismatrix(v)
    error('DIP:SourceShape','Expected a scalar annotation for %s',string(row.id))
end
switch string(row.dataset)
    case "Oxford"
        mask = v == 1;
    case {"LEMS","MPEG7","UPF"}
        v = double(v);
        bg = median([median(v(1,:)),median(v(:,1)),median(v(:,end))]);
        mask = v ~= bg;
    otherwise
        error('DIP:SourceDataset','Unknown dataset %s',string(row.dataset))
end
if ~isequal(size(mask),[double(row.h) double(row.w)]) || ~strcmp(pixelHash(mask),string(row.pixel_sha256))
    error('DIP:PixelHash','Decoded pixel hash or dimensions differ for %s',string(row.id))
end
end

function bytes = readBytes(path)
fid = fopen(path,'rb');
assert(fid>=0,'dip:Open','无法读取 %s',path)
closeFile = onCleanup(@() fclose(fid));
bytes = fread(fid,Inf,'*uint8').';
end


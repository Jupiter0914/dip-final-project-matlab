function writeJson(file,value)
fid = fopen(file,'w','n','UTF-8');
assert(fid>=0,'dip:Write','无法写入 %s',file)
closer = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(value));
end


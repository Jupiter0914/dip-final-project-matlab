function rows=archiveTrajectory(root,id,budget,method,original,fast)
%相同内容只写一份，两端收到的原始字节分别重新计算摘要
folder=fullfile(root,'local','perf','validation_blobs');
if ~isfolder(folder),mkdir(folder);end
assert(numel(original)==numel(fast)); rows=cell(numel(original),22);
for j=1:numel(original)
    a=original(j);b=fast(j);
    left=string(sha256Bytes(a.bytes));right=string(sha256Bytes(b.bytes));
    assert(left==right && isequal(a.bytes,b.bytes) && a.nbytes==b.nbytes && a.xor==b.xor);
    path=fullfile(folder,left+".pm3");
    if isfile(path)
        assert(isequal(readBytes(path),a.bytes),'EF:Archive','Stored validation file differs');
    else
        %分片可能产生同摘要文件，先完整写到同一目录的私有临时文件再发布
        partial=tempname(folder); clean=onCleanup(@() clearPartial(partial));
        fid=fopen(partial,'wb');assert(fid>=0,'EF:Archive','Cannot write validation file');
        guard=onCleanup(@() fclose(fid));
        assert(fwrite(fid,a.bytes,'uint8')==a.nbytes);clear guard
        [published,msg]=movefile(partial,path);
        assert(published || isfile(path),'EF:Archive','Could not publish validation blob: %s',msg);
        assert(isequal(readBytes(path),a.bytes),'EF:Archive','Concurrent blob differs');
        clear clean
    end
    rows(j,:)={id,budget,method,a.round,left,right,a.nbytes,b.nbytes,a.xor,b.xor, ...
        a.donor,a.receiver,a.deleted_x,a.deleted_y,a.inserted_x,a.inserted_y, ...
        b.donor,b.receiver,b.deleted_x,b.deleted_y,b.inserted_x,b.inserted_y};
end
end

function clearPartial(path)
if isfile(path),delete(path);end
end

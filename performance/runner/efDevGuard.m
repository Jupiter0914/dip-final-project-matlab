function efDevGuard(root,stage,mode)
%把开发等价收据绑定到当前进程实际解析的快速内核
dirName=fullfile(root,'perf_results',stage); receipt=fullfile(dirName,'equivalence.json');
result=jsondecode(fileread(receipt));
assert(result.passed && result.mismatches==0 && result.sources==36 && result.synthetic>=520 ...
    && result.rounds>0 && result.reused_rings>0)
source=fileparts(which('efMeasure')); files=dir(fullfile(source,'*.m'));
names=sort(string({files.name})).'; digests=strings(size(names));
for i=1:numel(names),digests(i)=sha256Bytes(readBytes(fullfile(source,names(i))));end
sig=sha256Bytes(unicode2native(char(join(names+" "+digests,newline)),'UTF-8'));
path=fullfile(dirName,'equivalence.ok');
receiptSha=sha256Bytes(readBytes(receipt));
if strcmp(mode,'record')
    writeJson(path,struct('kernel_sha256',sig,'receipt_sha256',receiptSha,'files',table2struct(table(names,digests))));
else
    old=jsondecode(fileread(path));assert(strcmp(sig,old.kernel_sha256) && strcmp(receiptSha,old.receipt_sha256))
end
end

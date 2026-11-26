function efKernelSeal(root,version,decision)
%冻结已定实现，旧三百图仅用于后续等价回归
path=fullfile(root,'performance','selected_kernel.json');
assert(~isfile(path),'DIP:KernelLock','A selected kernel is already recorded')
dirs=[dir(fullfile(root,'performance','kernel','*.m'));dir(fullfile(root,'src','**','*.m'))];
files=struct('path',{},'sha256',{});
for i=1:numel(dirs)
    name=fullfile(dirs(i).folder,dirs(i).name);
    rel=replace(extractAfter(string(name),strlength(root)+1),filesep,'/');
    files(i)=struct('path',char(rel),'sha256',sha256Bytes(readBytes(name)));
end
gateDir=fullfile(root,'perf_results',version);g=jsondecode(fileread(fullfile(gateDir,'decision.json')));
assert(strcmp(g.decision,decision))
writeJson(path,struct('version',char(version),'decision',char(decision),'files',{files}, ...
    'development_gate_sha256',sha256Bytes(readBytes(fullfile(gateDir,'gate.csv'))), ...
    'development_decision_sha256',sha256Bytes(readBytes(fullfile(gateDir,'decision.json'))), ...
    'development_equivalence_sha256',sha256Bytes(readBytes(fullfile(gateDir,'equivalence.json'))), ...
    'reference','8b5835a415f1224076e318229f829b0856d5266e'));
end

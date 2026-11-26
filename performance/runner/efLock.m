function efLock(root,action)
%冻结包含既有参考源、两版内核、名单、方法顺序、统计与各个运行入口
lockPath=fullfile(root,'performance','formal_lock.json');
selected=jsondecode(fileread(fullfile(root,'configs','published_kernel.json')));
assert(strcmp(selected.decision,'GO'),'DIP:NoGO','Confirmation requires an eligible engineering decision')
for i=1:numel(selected.files)
    assert(strcmp(sha256Bytes(readBytes(fullfile(root,selected.files(i).path))),selected.files(i).sha256))
end
if strcmp(action,'create')
    assert(~isfile(lockPath));
    checked=jsondecode(fileread(fullfile(root,'perf_results','old300','equivalence_replay.json')));
    assert(checked.passed && checked.sources==300 && checked.calls==1200 && checked.archive.replayed_checkpoints>0)
    gateDir=fullfile(root,'perf_results',selected.version);
    assert(strcmp(sha256Bytes(readBytes(fullfile(gateDir,'gate.csv'))),selected.development_gate_sha256))
    roster=readtable(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv'),'TextType','string');
    assert(height(roster)==200 && numel(unique(roster.id))==200 && numel(unique(roster.pixel_sha256))==200)
    for layer=["near","holes","components","simple"]
        mask=roster.stratum==layer;assert(nnz(mask)==50 && nnz(mask & logical(roster.fixed48))==12)
    end
    efWriteSchedule(root,'create');
end
files=[dir(fullfile(root,'src','**','*.m'));dir(fullfile(root,'performance','**','*.m')); ...
    dir(fullfile(root,'performance','**','*.ps1'));dir(fullfile(root,'performance','**','*.json')); ...
    dir(fullfile(root,'data','manifests','exact_fast','exact_fast*.csv'));dir(fullfile(root,'data','manifests','exact_fast','exact_fast*.txt'));dir(fullfile(root,'data','manifests','dev.csv')); ...
    dir(fullfile(root,'performance','sampling','*.csv'));dir(fullfile(root,'performance','reference','files.csv'));dir(fullfile(root,'configs','published_kernel.json')); ...
    dir(fullfile(root,'data','manifests','frozen.csv'));dir(fullfile(root,'docs','optimization_plan.md'))];
paths=sort(replace(extractAfter(string(fullfile({files.folder},{files.name})).',strlength(root)+1),filesep,'/'));
paths=paths(paths~="performance/formal_lock.json");
hashes=strings(size(paths));
for i=1:numel(paths)
    bytes=readBytes(fullfile(root,paths(i)));bytes(bytes==13)=[];
    hashes(i)=sha256Bytes(bytes);
end
digest=sha256Bytes(unicode2native(char(join(paths+" "+hashes,newline)),'UTF-8'));
if strcmp(action,'create')
    assert(~isfile(lockPath));writeJson(lockPath,struct('sha256',digest,'files',table2struct(table(paths,hashes))));
else
    expected=jsondecode(fileread(lockPath));assert(strcmp(expected.sha256,digest),'DIP:Frozen','Formal sources or roster changed')
end
end

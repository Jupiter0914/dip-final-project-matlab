function signature = freezeExperiment(root,mode)
%用相对路径锁住生产内核、计时入口、配置和样本清单
lockPath = fullfile(root,'configs','freeze.json');
blocks = [dir(fullfile(root,'src','**','*.m')); dir(fullfile(root,'scripts','run_confirm.m')); ...
    dir(fullfile(root,'scripts','run_smoke.m'));dir(fullfile(root,'scripts','run_supplements.m')); ...
    dir(fullfile(root,'dip.m')); dir(fullfile(root,'docs','freeze_protocol.md')); dir(fullfile(root,'configs','confirm.json')); ...
    dir(fullfile(root,'data','manifests','*.csv'))];
paths = string(fullfile({blocks.folder},{blocks.name})).';
paths = sort(replace(extractAfter(paths,strlength(root)+1),filesep,'/'));
paths = paths(~startsWith(paths,'src/exploration/')); 
hashes = strings(size(paths));
for i=1:numel(paths)
    bytes = readBytes(fullfile(root,paths(i)));
    bytes(bytes==13) = [];
    hashes(i) = sha256Bytes(bytes);
end
signature = char(sha256Bytes(unicode2native(char(join(paths+" "+hashes,newline)),'UTF-8')));
if strcmp(mode,'create')
    if isfile(lockPath)
        error('dip:AlreadyFrozen','已有冻结记录；新研究应设置独立版本')
    end
    writeJson(lockPath,struct('sha256',signature,'files',table2struct(table(paths,hashes)), ...
        'date_utc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss'))));
else
    old = jsondecode(fileread(lockPath));
    assert(strcmp(old.sha256,signature),'dip:FreezeChanged','冻结源文件或配置发生变化')
end
end


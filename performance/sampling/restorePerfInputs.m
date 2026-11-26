function restorePerfInputs(root)
%按已经冻结的文件身份恢复正式标注，不重新排序或选源
addpath(genpath(fullfile(root,'src')));
manifest=fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv');
assert(isfile(manifest) && isfile(fullfile(root,'performance','formal_lock.json')))
rows=readtable(manifest,'TextType','string');assert(height(rows)==200)
archive=fullfile(root,'local','perf','official','annotations.tar.gz');
if ~isfile(archive)
    if ~isfolder(fileparts(archive)),mkdir(fileparts(archive));end
    websave(archive,'https://thor.robots.ox.ac.uk/datasets/pets/annotations.tar.gz');
end
assert(strcmp(sha256Bytes(readBytes(archive)),'52425fb6de5c424942b7626b428656fcbd798db970a937df61750c0f1d358e91'))
tmp=tempname;mkdir(tmp);guard=onCleanup(@()rmdir(tmp,'s'));untar(archive,tmp);
for i=1:height(rows)
    src=fullfile(tmp,'annotations','trimaps',rows.id(i)+".png");
    assert(strcmp(sha256Bytes(readBytes(src)),rows.raw_sha256(i)))
    target=fullfile(root,rows.file(i));folder=fileparts(target);
    if ~isfolder(folder),mkdir(folder);end
    if ~isfile(target),copyfile(src,target);end
    readFrozenMask(root,rows(i,:));
end
end

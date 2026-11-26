function stamp=validationKernel(root,label)
%开发轮次优先加载归档的同名实现，避免重放第一轮时误用最后一次尝试
label=string(label);
folder=fullfile(root,'performance','kernel');
if startsWith(label,"old300") || label=="selected"
    L=jsondecode(fileread(fullfile(root,'configs','published_kernel.json')));
    paths=string({L.files.path}); idx=find(endsWith(replace(paths,"\","/"),"/efMeasure.m"));
    assert(numel(idx)==1,'EF:WrongKernel','Lock must specify exactly one efMeasure.m');
    selected=fullfile(root,paths(idx)); archived=string(fileparts(selected));
    for j=1:numel(L.files)
        assert(strcmp(sha256Bytes(readBytes(fullfile(root,L.files(j).path))),L.files(j).sha256),'EF:Freeze','Locked file hash differs');
    end
elseif startsWith(label,"dev1") || label=="v1"
    archived=fullfile(root,'performance','versions','v1');
elseif startsWith(label,"dev2") || label=="v2"
    archived=fullfile(root,'performance','versions','v2');
else
    archived="";
end
if strlength(archived)>0 && isfile(fullfile(archived,'efMeasure.m')),folder=archived;end
addpath(folder,'-begin'); rehash;
assert(strcmpi(which('efMeasure'),fullfile(folder,'efMeasure.m')),'EF:WrongKernel','Incorrect fast entry point');
files=dir(fullfile(folder,'**','*.m')); entries=struct('path',{},'sha256',{});
for i=1:numel(files)
    path=fullfile(files(i).folder,files(i).name);
    [~,name]=fileparts(path);
    if startsWith(name,'ef')
        assert(strcmpi(which(name),path),'EF:WrongKernel','Different kernel supplied %s',name);
    end
    entries(i)=struct('path',replace(extractAfter(string(path),strlength(string(root))+1),"\","/"),...
        'sha256',string(sha256Bytes(readBytes(path))));
end
stamp=struct('label',label,'files',{entries},'reference_entry', ...
    string(sha256Bytes(readBytes(fullfile(root,'src','evaluation','measureEncoding.m')))));
end

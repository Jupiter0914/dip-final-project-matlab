function efSetup(root,versionId)
%每个新进程只装载一个快速内核，参考实现始终从原目录解析
if nargin<2,versionId="current";end
addpath(genpath(fullfile(root,'src')),fullfile(root,'scripts'));
for sub=["runner","validation","profile","analysis","sampling"]
    addpath(fullfile(root,'performance',sub));
end
kernel=fullfile(root,'performance','kernel');
if string(versionId)=="dev1" && isfolder(fullfile(root,'performance','versions','v1'))
    kernel=fullfile(root,'performance','versions','v1');
end
addpath(kernel)
assert(strcmp(which('measureEncoding'),fullfile(root,'src','evaluation','measureEncoding.m')))
assert(strcmp(which('efMeasure'),fullfile(kernel,'efMeasure.m')))
files=readtable(fullfile(root,'performance','reference','files.csv'),'TextType','string');
for i=1:height(files)
    bytes=readBytes(fullfile(root,files.file(i)));
    if ~strcmp(sha256Bytes(bytes),files.sha256(i))
        error('DIP:ReferenceModified','Reference differs: %s',files.file(i))
    end
end
end

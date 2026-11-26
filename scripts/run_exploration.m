function run_exploration(study)
%探索记录独立保存，只读取清单中允许开发的正式训练验证图
if nargin==0, study="all"; end
study=string(study); assert(ismember(study,["all","single","pso","controls","allocation","verify"]));
root=fileparts(fileparts(mfilename('fullpath'))); addpath(genpath(fullfile(root,'src')));
manifest=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
assert(height(manifest)==36 && all(manifest.official=="trainval"));
out=fullfile(root,'results','exploration'); if ~isfolder(out), mkdir(out); end
if study=="all" || study=="single"
    selected=ismember(manifest.id,["pomeranian_10","pug_127","British_Shorthair_187"]);
    assert(nnz(selected)==3); exploreSingle(root,manifest(selected,:),out);
end
if study=="all" || study=="pso", explorePSO(root,manifest,out); end
if study=="all" || study=="controls", exploreWithinControls(root,manifest,out); end
if study=="all" || study=="allocation", exploreAllocation(root,manifest,out); end
if study=="all" || study=="verify", verifyExploration(root,manifest,out); end
end

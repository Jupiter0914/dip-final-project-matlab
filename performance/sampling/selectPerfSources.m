function selected=selectPerfSources(root,gateDir)
%开发工程判定通过才解开官方归档、计算候选排序或写入新确认清单
addpath(genpath(fullfile(root,'src')));
decision=jsondecode(fileread(fullfile(gateDir,'decision.json')));assert(decision.go && string(decision.decision)=="GO",'PERF:NoGO','Independent selection requires development GO');
gate=readtable(fullfile(gateDir,'gate.csv'),'TextType','string');gate=gate(gate.scope=="all",:);
for method=["cross","within","geom","geom_within"]
    first=gate(gate.method==method & gate.metric=="first",:);total=gate(gate.method==method & gate.metric=="total",:);
    assert(height(first)==1 && first.ratio>0 && first.ratio<=1.05 && height(total)==1 && total.ratio>0);
    if method=="cross",assert(total.ratio<=.90 && all([total.s1 total.s2 total.s3]<1));else,assert(total.ratio<=1.05);end
end
rosterFolder=fullfile(root,'data','manifests','exact_fast');if ~isfolder(rosterFolder),mkdir(rosterFolder);end
dest=fullfile(rosterFolder,'exact_fast_confirm.csv');assert(~isfile(dest),'PERF:ExistingSelection','The new manifest is already present');
where=fileparts(mfilename('fullpath'));
screenPath=fullfile(where,'oxford_historical_screen.csv');viewsPath=fullfile(where,'oxford_historical_views.csv');
screenBytes=readBytes(screenPath);viewBytes=readBytes(viewsPath);
assert(strcmp(sha256Bytes(screenBytes(screenBytes~=13)),'d6e45b9b9b38a9166de4cba1a704db91ec83bda160429b39d7621df551e97617'));
assert(strcmp(sha256Bytes(viewBytes(viewBytes~=13)),'fc75caacd5755fc774e0d49583d36909299aed7737d96bc56758cd11b9869d5c'));
hist=readtable(fullfile(where,'oxford_historical_screen.csv'),'TextType','string');views=readtable(fullfile(where,'oxford_historical_views.csv'),'TextType','string');
assert(height(hist)==3705 && numel(unique(hist.id))==3705 && height(views)==372);
archive=fullfile(root,'local','perf','official','annotations.tar.gz');
if ~isfile(archive)
    parent=fileparts(archive);if ~isfolder(parent),mkdir(parent);end
    websave(archive,'https://thor.robots.ox.ac.uk/datasets/pets/annotations.tar.gz',weboptions('Timeout',180));
end
assert(strcmp(sha256Bytes(readBytes(archive)),'52425fb6de5c424942b7626b428656fcbd798db970a937df61750c0f1d358e91'),'PERF:Archive','Official release digest differs');
%临时根目录只包含本轮核过摘要的官方原包
unpack=tempname;mkdir(unpack);closer=onCleanup(@()cleanTemp(unpack));untar(archive,unpack);
testList=fullfile(unpack,'annotations','test.txt');assert(strcmp(sha256Bytes(readBytes(testList)),'a5454003774ffe01f4f322756d3ba5495bae21cb30bb217ab285dbfa2bef245c'));
officialBytes=readBytes(testList);officialDest=fullfile(root,'data','manifests','exact_fast','exact_fast_official_test.txt');
if isfile(officialDest)
    assert(isequal(readBytes(officialDest),officialBytes),'PERF:OfficialListChanged','Existing official test list differs');
else
    copyfile(testList,officialDest);assert(isequal(readBytes(officialDest),officialBytes));
end
lines=strip(readlines(testList));lines=lines(strlength(lines)>0 & ~startsWith(lines,"#"));members=extractBefore(lines," ");
assert(numel(members)==3669 && numel(unique(members))==3669 && all(ismember(members,hist.id)));
old=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');old=old(old.dataset=="Oxford",:);
dev=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
denied=ismember(hist.disposition,["known_source","selected","touches_excluded_family","excluded_prefix_or_missing_rgb"]);
blockedFamilies=unique([hist.family(denied);old.family]);oldIds=unique([hist.id(denied);old.id;dev.id;views.parent_id;views.id]);
oldRaw=unique([hist.raw_sha256(denied);old.raw_sha256;dev.raw_sha256;views.raw_sha256;views.parent_raw_sha256]);
oldPixels=unique([hist.pixel_sha256(denied);old.pixel_sha256;dev.pixel_sha256;views.pixel_sha256]);
%旧图谱含同拍、镜像、旋转、外圈派生及近重复家族，保留每个未用家族的历史代表
keep=ismember(hist.id,members) & hist.disposition=="not_selected_by_quota" & ~ismember(hist.family,blockedFamilies) & ~ismember(lower(hist.id),lower(oldIds)) & ~ismember(hist.raw_sha256,oldRaw) & ~ismember(hist.pixel_sha256,oldPixels);
pool=hist(keep,:);assert(numel(unique(pool.family))==height(pool));
pool.rank=hashOrder(pool.id,"43129|exact-fast-confirm-v1|");groups=["near","holes","components","simple"];idx=[];counts=zeros(4,2);
for i=1:4
    ix=find(pool.stratum==groups(i));[~,order]=sort(pool.rank(ix));ix=ix(order);counts(i,:)=[numel(ix),min(50,numel(ix))];idx=[idx;ix(1:counts(i,2))];
end
out=fullfile(root,'perf_results','sampling');if ~isfolder(out),mkdir(out);end
writetable(table(groups.',counts(:,1),counts(:,2),'VariableNames',{'stratum','eligible','selected'}),fullfile(out,'quota.csv'));
assert(all(counts(:,2)==50),'PERF:Quota','Insufficient new families. See quota.csv');
selected=pool(idx,:);assert(numel(unique(selected.family))==200 && numel(unique(selected.pixel_sha256))==200 && numel(unique(selected.raw_sha256))==200);
selected.official=repmat("test",height(selected),1);selected.fixed48=false(height(selected),1);selected.subset_rank=hashOrder(selected.id,"43129|exact-fast-fixed-v1|");
selected.file="data/exact_fast/Oxford/"+selected.id+".png";selected.member="annotations/trimaps/"+selected.id+".png";
selected.w=zeros(height(selected),1);selected.h=selected.w;selected.rings=selected.w;selected.components=selected.w;selected.holes=selected.w;selected.near=selected.w;selected.group=selected.category;
for i=1:4
    ix=find(selected.stratum==groups(i));[~,order]=sort(selected.subset_rank(ix));selected.fixed48(ix(order(1:12)))=true;
end
sourceDir=fullfile(root,'data','exact_fast','Oxford');if ~isfolder(sourceDir),mkdir(sourceDir);end
for k=1:height(selected)
    src=fullfile(unpack,selected.member(k));assert(strcmp(sha256Bytes(readBytes(src)),selected.raw_sha256(k)),'PERF:RawMismatch','Input differs on %s',selected.id(k));
    raw=imread(src)==1;assert(strcmp(pixelHash(raw),selected.pixel_sha256(k)),'PERF:PixelMismatch','Pixel digest differs on %s',selected.id(k));
    [h,w]=size(raw);selected.h(k)=h;selected.w(k)=w;
    [s,nf,nh,near]=perfStratum(raw);assert(s==selected.stratum(k),'PERF:StratumMismatch','Input descriptor mismatch for %s (%s vs %s)',selected.id(k),s,selected.stratum(k));
    selected.rings(k)=nf+nh;selected.components(k)=nf;selected.holes(k)=nh;selected.near(k)=near;
    copyfile(src,fullfile(root,selected.file(k)));
end
selected.disposition=[];writetable(selected,dest);writetable(selected(selected.fixed48,:),fullfile(root,'data','manifests','exact_fast','exact_fast_fixed48.csv'));
inputOnly=table(height(hist),numel(members),nnz(denied),numel(oldIds),numel(blockedFamilies),height(pool),height(selected),nnz(selected.fixed48),...
    'VariableNames',{'catalogue_rows','official_test','historical_denied_rows','denied_ids_and_aliases','denied_families','eligible_families','selected','fixed48'});
writetable(inputOnly,fullfile(out,'screening.csv'));
audit=hist;audit.official_test=ismember(audit.id,members);audit.previously_known_id=ismember(lower(audit.id),lower(oldIds));
audit.previously_used_family=ismember(audit.family,blockedFamilies);audit.duplicate_raw=ismember(audit.raw_sha256,oldRaw);audit.duplicate_pixels=ismember(audit.pixel_sha256,oldPixels);
audit.eligible=keep;audit.chosen=ismember(audit.id,selected.id);audit.fixed48=ismember(audit.id,selected.id(selected.fixed48));audit.rank=strings(height(audit),1);audit.rank(keep)=pool.rank;
audit.exclusion=repmat("eligible_outside_quota",height(audit),1);
audit.exclusion(~keep)="historical_nonrepresentative";audit.exclusion(audit.duplicate_pixels)="known_pixel_sha";audit.exclusion(audit.duplicate_raw)="known_raw_sha";
audit.exclusion(audit.previously_used_family)="known_or_used_family";audit.exclusion(audit.previously_known_id)="known_id_or_alias";
audit.exclusion(~audit.official_test)="not_official_test";audit.exclusion(audit.chosen)="selected";
[w,labels]=findgroups(audit(:,{'stratum','exclusion'}));labels.sources=splitapply(@numel,audit.id,w);
writetable(audit,fullfile(out,'candidates_and_exclusions.csv'));writetable(labels,fullfile(out,'exclusion_counts.csv'));
paths=["local/perf/official/annotations.tar.gz";"data/manifests/exact_fast/exact_fast_official_test.txt";"performance/sampling/oxford_historical_screen.csv";...
    "performance/sampling/oxford_historical_views.csv";"data/manifests/frozen.csv";"data/manifests/dev.csv";"data/manifests/exact_fast/exact_fast_confirm.csv";"data/manifests/exact_fast/exact_fast_fixed48.csv"];
roles=["官方原始标注归档";"官方测试总体原始名单";"历史Oxford整族筛查与排重";"历史Oxford派生视图与父源";"基础实验确认成员";"历史获准开发成员";"本次新确认成员";"本次固定工作量子集"];
totals=[NaN;numel(members);height(hist);height(views);height(readtable(fullfile(root,paths(5))));height(dev);height(selected);nnz(selected.fixed48)];
digests=strings(size(paths));normalization=repmat("LF_text",numel(paths),1);normalization(1:2)="original_bytes";
for i=1:numel(paths)
    bytes=readBytes(fullfile(root,paths(i)));if i>2,bytes(bytes==13)=[];end
    digests(i)=sha256Bytes(bytes);
end
population=table(roles,paths,totals,digests,normalization,'VariableNames',{'role','source_path','rows','sha256','hash_scope'});
writetable(population,fullfile(root,'data','manifests','exact_fast','exact_fast_population.csv'));
auditPerfRoster(root);
end

function h=hashOrder(ids,salt)
h=strings(numel(ids),1);
for k=1:numel(ids),h(k)=sha256Bytes(unicode2native(char(salt+"Oxford|"+ids(k)),'UTF-8'));end
end


function cleanTemp(path)
p=char(java.io.File(path).getCanonicalPath());base=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(lower(p),lower([base filesep])) && ~strcmpi(p,base),'PERF:TempPath','Unsafe temp path');rmdir(p,'s');
end

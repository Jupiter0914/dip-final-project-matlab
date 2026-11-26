function receipt=auditPerfRoster(root)
%只读已经存在的名单，用独立的排序与排除流程复算，无编码器和计时依赖
addpath(genpath(fullfile(root,'src')),fullfile(root,'performance','sampling'));
base=fullfile(root,'data','manifests');where=fileparts(mfilename('fullpath'));
official=fullfile(base,'exact_fast','exact_fast_official_test.txt');native=readBytes(official);officialHash=string(sha256Bytes(native));
assert(officialHash=="a5454003774ffe01f4f322756d3ba5495bae21cb30bb217ab285dbfa2bef245c",'PERF:OfficialRoster','Official test list hash differs');
text=regexp(char(native),'(?m)^([A-Za-z0-9_]+)\s+\d+\s+\d+\s+\d+\s*$','tokens');
ids=string(cellfun(@(v)v{1},text,'UniformOutput',false)).';assert(numel(ids)==3669 && numel(unique(ids))==3669);
legacy=readtable(fullfile(where,'oxford_historical_screen.csv'),'TextType','string');views=readtable(fullfile(where,'oxford_historical_views.csv'),'TextType','string');
frozen=readtable(fullfile(base,'frozen.csv'),'TextType','string');old=frozen(frozen.dataset=="Oxford",:);dev=readtable(fullfile(base,'dev.csv'),'TextType','string');
picked=readtable(fullfile(base,'exact_fast','exact_fast_confirm.csv'),'TextType','string');fixed=readtable(fullfile(base,'exact_fast','exact_fast_fixed48.csv'),'TextType','string');
assert(height(legacy)==3705 && height(views)==372 && height(old)==200 && height(dev)==36);
assert(height(picked)==200 && height(fixed)==48 && all(picked.dataset=="Oxford") && all(picked.official=="test"));
assert(numel(unique(picked.id))==200&&numel(unique(picked.family))==200&&numel(unique(picked.raw_sha256))==200&&numel(unique(picked.pixel_sha256))==200);
assert(all(ismember(picked.id,ids)) && isequal(sort(picked.id(logical(picked.fixed48))),sort(fixed.id)));
assert(isequal(sortrows(fixed,'id'),sortrows(picked(logical(picked.fixed48),:),'id')),'PERF:FixedRoster','Subset content differs from its rows in the main roster');
population=readtable(fullfile(base,'exact_fast','exact_fast_population.csv'),'TextType','string');
expectedPaths=["local/perf/official/annotations.tar.gz";"data/manifests/exact_fast/exact_fast_official_test.txt";"performance/sampling/oxford_historical_screen.csv";...
    "performance/sampling/oxford_historical_views.csv";"data/manifests/frozen.csv";"data/manifests/dev.csv";"data/manifests/exact_fast/exact_fast_confirm.csv";"data/manifests/exact_fast/exact_fast_fixed48.csv"];
assert(isequal(population.source_path,expectedPaths) && isequal(population.rows(2:end),[numel(ids);height(legacy);height(views);height(frozen);height(dev);height(picked);height(fixed)]));
assert(population.sha256(1)=="52425fb6de5c424942b7626b428656fcbd798db970a937df61750c0f1d358e91" && population.sha256(2)==officialHash);
assert(population.sha256(3)=="d6e45b9b9b38a9166de4cba1a704db91ec83bda160429b39d7621df551e97617" && population.sha256(4)=="fc75caacd5755fc774e0d49583d36909299aed7737d96bc56758cd11b9869d5c");
archiveVerified=false;
for j=1:height(population)
    f=fullfile(root,population.source_path(j));
    if j==1 && ~isfile(f),continue;end
    bytes=readBytes(f);if j>2,bytes(bytes==13)=[];end
    assert(strcmp(sha256Bytes(bytes),population.sha256(j)),'PERF:PopulationHash','Population source mismatch');
    if j==1,archiveVerified=true;end
end
%先以官方测试ID联结历史输入描述，同族代表以外的条目均不参与排序
denied=legacy(ismember(legacy.disposition,["known_source","selected","touches_excluded_family","excluded_prefix_or_missing_rgb"]),:);
foreignIds=lower([denied.id;old.id;dev.id;views.id;views.parent_id]);families=[denied.family;old.family];
rawBlock=[denied.raw_sha256;old.raw_sha256;dev.raw_sha256;views.raw_sha256;views.parent_raw_sha256];
pixelBlock=[denied.pixel_sha256;old.pixel_sha256;dev.pixel_sha256;views.pixel_sha256];
pool=innerjoin(table(ids,'VariableNames',{'id'}),legacy,'Keys','id');assert(height(pool)==numel(ids) && numel(unique(pool.id))==numel(ids));
pool=pool(pool.disposition=="not_selected_by_quota",:);pool=pool(~ismember(lower(pool.id),foreignIds),:);
pool=pool(~ismember(pool.family,families),:);pool=pool(~ismember(pool.raw_sha256,rawBlock) & ~ismember(pool.pixel_sha256,pixelBlock),:);
assert(numel(unique(pool.family))==height(pool));strata=["near","holes","components","simple"];counts=zeros(4,3);
for j=1:4
    t=pool(pool.stratum==strata(j),:);t.checkRank=strings(height(t),1);
    for k=1:height(t),t.checkRank(k)=keyHash("43129|exact-fast-confirm-v1|Oxford|",t.id(k));end
    t=sortrows(t,{'checkRank','id'});v=picked(picked.stratum==strata(j),:);
    assert(height(v)==50 && nnz(logical(v.fixed48))==12 && height(t)>=50);gold=t(1:50,:);
    assert(isequal(v.id,gold.id) && isequal(v.rank,gold.checkRank));assert(isequal(v.raw_sha256,gold.raw_sha256)&&isequal(v.pixel_sha256,gold.pixel_sha256)&&isequal(v.family,gold.family) && isequal(v.family_size,gold.family_size) && isequal(v.category,gold.category) && isequal(v.rgb_sha256,gold.rgb_sha256));
    subsetKey=strings(50,1);for k=1:50,subsetKey(k)=keyHash("43129|exact-fast-fixed-v1|Oxford|",gold.id(k));end
    assert(isequal(subsetKey,v.subset_rank));order=sortrows(table(subsetKey,gold.id,'VariableNames',{'hash','id'}),{'hash','id'});
    assert(isequal(sort(order.id(1:12)),sort(v.id(logical(v.fixed48)))));counts(j,:)=[height(t),height(v),nnz(logical(v.fixed48))];
end
for j=1:height(picked)
    row=picked(j,:);assert(row.file=="data/exact_fast/Oxford/"+row.id+".png" && row.member=="annotations/trimaps/"+row.id+".png");
    m=readFrozenMask(root,row);[s,nf,nh,near]=perfStratum(m);
    assert(s==row.stratum && nf==row.components && nh==row.holes && near==row.near && nf+nh==row.rings);
end
receipt=struct('passed',true,'official_test_sources',numel(ids),'official_test_original_sha256',officialHash,'archive_digest_verified_locally',archiveVerified, ...
    'historical_screen_rows',height(legacy),'historical_derived_views',height(views),'eligible_families',height(pool),'raw_pixel_dimensions_verified',height(picked), ...
    'main_replayed',height(picked),'fixed_replayed',height(fixed),'strata',strata,'eligible_main_fixed_counts',counts,'recomputed_population_rows',height(population));
out=fullfile(root,'perf_results','sampling');if ~isfolder(out),mkdir(out);end
writeJson(fullfile(out,'independent_check.json'),receipt);
end

function digest=keyHash(salt,id)
digest=string(sha256Bytes(unicode2native(char(strcat(salt,id)),'UTF-8')));
end

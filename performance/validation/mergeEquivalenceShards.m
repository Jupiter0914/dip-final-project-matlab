function receipt=mergeEquivalenceShards(label)
%两个互斥分片独立完成后，验证实际源集合、共同锁、全部检查点，再产生总体回执
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(genpath(fullfile(root,'src')));
label=string(label);out=fullfile(root,'perf_results',label);
assert(startsWith(label,"old300") && maxNumCompThreads==1);
manifest=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');expected=manifest.dataset+"/"+manifest.id;
names=["equivalence_calls","equivalence_rounds","equivalence_checkpoints"]; merged=cell(3,1); receipts=cell(2,1);
for j=1:2
    folder=fullfile(out,"shard"+j);
    unit=jsondecode(fileread(fullfile(folder,'equivalence.json')));receipts{j}=unit;
    assert(unit.passed && unit.shard==j && unit.n_shards==2 && unit.sources==150 && unit.calls==600 && unit.mismatches==0);
    stamp=jsondecode(fileread(fullfile(folder,'kernel_stamp.json')));
    lock=fullfile(root,'performance','selected_kernel.json');
    if isfield(stamp,'public_source_manifest') && stamp.public_source_manifest
        lock=fullfile(root,'configs','published_kernel.json');
    end
    assert(strcmp(stamp.selected_lock_sha256,sha256Bytes(readBytes(lock))));
    if j==1,common=stamp;else,assert(isequal(common,stamp),'EF:Freeze','Validation shards used different source hashes');end
    checked=jsondecode(fileread(fullfile(folder,'equivalence_replay.json'))); assert(checked.passed);
    assert(strcmp(checked.source_calls_sha256,sha256Bytes(readBytes(fullfile(folder,'equivalence_calls.csv')))));
    assert(strcmp(checked.source_rounds_sha256,sha256Bytes(readBytes(fullfile(folder,'equivalence_rounds.csv')))));
    assert(strcmp(checked.archive.checkpoints_csv_sha256,sha256Bytes(readBytes(fullfile(folder,'equivalence_checkpoints.csv')))));
    for k=1:numel(names)
        t=readtable(fullfile(folder,names(k)+".csv"),'TextType','string');
        if k==1,assert(isequal(sort(unique(t.id)),sort(expected(j:2:end))));end
        if j==1,merged{k}=t;else,merged{k}=[merged{k};t];end
    end
end
C=merged{1};assert(height(C)==1200 && height(unique(C(:,{'id','method','budget'})))==1200 && isequal(sort(unique(C.id)),sort(expected)));
for i=1:numel(common.files),assert(strcmp(sha256Bytes(readBytes(fullfile(root,common.files(i).path))),common.files(i).sha256));end
for k=1:numel(names)
    tbl=merged{k};order={'id','budget','method'};if ismember('round',tbl.Properties.VariableNames),order{end+1}='round';end
    writetable(sortrows(tbl,order),fullfile(out,names(k)+".csv"));
end
receipt=receipts{1};fields={'sources','synthetic','calls','rounds','outputs','single_deletions','single_insertions', ...
    'legal_pairs','top_pairs','actual_full_checks','reused_rings','rebuilt_rings','accepted_cross','accepted_within','accepted_triangle'};
if isfield(receipt,'pixel_checked_edits'),fields=[fields,{'pixel_checked_edits','pixel_ids_compared','fallbacks'}];end
for i=1:numel(fields),f=fields{i};receipt.(f)=receipts{1}.(f)+receipts{2}.(f);end
receipt.shard=0;receipt.n_shards=2;
assert(receipt.calls==1200 && receipt.sources==300 && receipt.mismatches==0);
writeJson(fullfile(out,'kernel_stamp.json'),common);
verified=replayEquivalence(label,root,receipt);assert(verified.passed);
writeJson(fullfile(out,'equivalence.json'),receipt);disp(receipt);
end

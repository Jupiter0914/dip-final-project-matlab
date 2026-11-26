function receipt=finalizeEquivalence(label,root)
%长时轨迹全部写盘后，独立重放成功才发布最终验收回执
if nargin<2,root=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(genpath(fullfile(root,'src')));
out=fullfile(root,'perf_results',label);
receipt=jsondecode(fileread(fullfile(out,'semantic_measurements.json')));
assert(receipt.passed && receipt.mismatches==0);
verified=replayEquivalence(label,root,receipt);assert(verified.passed);
writeJson(fullfile(out,'equivalence.json'),receipt);
end

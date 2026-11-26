function verify_primary_tables(root)
%从公开配对记录重算两个主要终点，按重复、会话、来源逐层汇总
if nargin == 0, root = fileparts(fileparts(mfilename('fullpath'))); end
addpath(fullfile(root,'performance','analysis'));
folder = fullfile(root,'perf_results','output');
claims = jsondecode(fileread(fullfile(folder,'formal_claims.json')));
fixed = readtable(fullfile(folder,'fixed_pairs.csv'),'TextType','string');
a = fixed(fixed.method=="cross" & fixed.metric=="return_ms" & fixed.eligibility=="paired",:);
assert(all(a.old_trace_sha==a.fast_trace_sha & a.old_final_sha==a.fast_final_sha))
times = sourceMeans(a,log(a.fast_return_ms ./ a.old_return_ms));
quality = readtable(fullfile(folder,'timed_pairs.csv'),'TextType','string');
b = quality(quality.method=="fast_cross" & quality.baseline=="fast_within" & ...
    quality.deadline==100 & quality.fast_rings>=2 & quality.common==1,:);
assert(all(b.old_nbytes==b.fast_nbytes & b.old_received_ms<=100 & b.fast_received_ms<=100))
gains = sourceMeans(b,b.old_xor-b.fast_xor);
assert(numel(times)==48 && height(a)==288)
assert(numel(gains)==claims.quality_sources && height(b)==claims.quality_pairs)
ratio = exp(mean(times));
gain = mean(gains);
assert(abs(ratio-claims.fixed_cross_ratio)<1e-10 && abs(gain-claims.mean_xor_gain)<1e-10)
assert(max(abs(exp(perfCI(times))-[claims.A_ci95(:);claims.A_ci975(:)].'))<1e-10)
assert(max(abs(perfCI(gains)-[claims.B_ci95(:);claims.B_ci975(:)].'))<1e-10)
fprintf('固定工作量：%d 源，%d 对，耗时比 %.5f\n',numel(times),height(a),ratio)
fprintf('100 ms 多环：%d 源，%d 对，平均错分差 %.5f 像素\n',numel(gains),height(b),gain)
end

function values = sourceMeans(rows, metric)
[groups,ids] = findgroups(rows.id,rows.session);
bySession = splitapply(@mean,metric,groups);
values = splitapply(@mean,bySession,findgroups(ids));
end

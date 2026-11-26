function audit_missingness(root)
%确认失败行的质量和文件身份都留空，每个空值都有对应的时点状态
folder=fullfile(root,'results');
obs=readtable(fullfile(folder,'observations.csv'),'TextType','string');
runs=readtable(fullfile(folder,'runs.csv'),'TextType','string');
allowed=["success","below_proved_lower_bound","search_no_valid_output","unsupported_representation","program_error"];
assert(all(ismember(runs.status,allowed)) && all(ismember(obs.status,[allowed,"not_ready"])))
assert(all(isfinite(runs.return_ms) & runs.return_ms>=0) && all(isfinite(runs.search_end_ms)))
assert(all(runs.search_end_ms<=runs.return_ms+1e-10))
good=obs.status=="success"; numericFields={'nbytes','xor','fp','fn','iou','rmse','received_ms'};
for k=1:numel(numericFields)
    v=obs.(numericFields{k});
    assert(all(isfinite(v(good))) && all(isnan(v(~good))))
end
assert(all(strlength(obs.sha256(good))==64))
assert(all(ismissing(obs.sha256(~good)) | strlength(obs.sha256(~good))==0))
assert(all(obs.xor(good)==obs.fp(good)+obs.fn(good)))
assert(all(obs.iou(good)>=0 & obs.iou(good)<=1 & obs.rmse(good)>=0 & obs.rmse(good)<=1))
key={'dataset','id','session','rep','budget','method'};
joined=innerjoin(obs(:,[key,{'deadline','status'}]),renamevars(runs(:,[key,{'status','return_ms'}]),'status','terminal'),'Keys',key);
assert(height(joined)==height(obs))
no=joined.status~="success";
beforeReturn=joined.return_ms>joined.deadline;
assert(all(joined.status(no & beforeReturn)=="not_ready"))
after=no & ~beforeReturn;
assert(all(joined.status(after)==joined.terminal(after)))
assert(all(isfinite(obs.rings(good)) & obs.rings(good)>=0))
s=readtable(fullfile(folder,'summary.csv'),'TextType','string');
assert(all(isfinite(s.mean_gain(s.n_sources>0))) && all(isnan(s.mean_gain(s.n_sources==0))))
assert(all(s.wins+s.ties+s.losses==s.n_sources))
assert(all(isfinite(s.mean_complete(s.n_complete>0))) && all(isnan(s.mean_complete(s.n_complete==0))))
writeJson(fullfile(folder,'missingness_check.json'),struct('observations',height(obs), ...
    'success',nnz(good),'unavailable',nnz(~good),'program_exceptions',nnz(runs.status=="program_error"), ...
    'summary_rows_without_eligible_sources',nnz(s.n_sources==0),'unexplained_missing_quality',0))
end

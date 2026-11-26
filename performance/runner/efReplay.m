function report=efReplay(root)
%只读保存的接收字节和逐次日志，重算工程门槛及已开展的确认统计
if nargin==0,root=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
efSetup(root,'current');
lock=jsondecode(fileread(fullfile(root,'configs','published_kernel.json')));
ref=jsondecode(fileread(fullfile(root,'performance','reference','verification.json')));
assert(strcmp(sha256Bytes(readBytes(fullfile(root,'performance','reference','files.csv'))),ref.public_files_sha256))
for k=1:numel(lock.files)
    assert(strcmp(sha256Bytes(readBytes(fullfile(root,lock.files(k).path))),lock.files(k).sha256))
end
out=fullfile(root,'perf_results');
for stage=["dev1","dev2"]
    if stage=="dev2" && ~isfolder(fullfile(out,stage)),continue;end
    efSetup(root,stage);efDevGuard(root,stage,'verify');replayEquivalence(stage,root);efCollect(root,stage);
    old=jsondecode(fileread(fullfile(out,stage,'decision.json')));
    now=efGate(root,stage);
    assert(old.go==now.go && abs(old.cross_ratio-now.cross_ratio)<1e-12)
end
efSetup(root,'current');
replayEquivalence('old300',root);
if strcmp(lock.decision,'GO')
    efLock(root,'verify');efWriteSchedule(root,'verify');auditPerfRoster(root);
    efCollect(root,'timed');efCollect(root,'fixed');perfAnalysis(root,'formal');
else
    assert(~isfile(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv')))
    perfAnalysis(root,'no-go');
end
efAuditPlots(root,strcmp(lock.decision,'GO'));
report=struct('decision',lock.decision,'candidate',lock.version,'native_matlab',version);
report.reference=ref.baseline;report.old300=jsondecode(fileread(fullfile(out,'old300','equivalence.json')));
report.development_calls=0;
for stage=["dev1","dev2"]
    file=fullfile(out,stage,'journal_audit.json');
    if isfile(file),x=jsondecode(fileread(file));report.development_calls=report.development_calls+x.calls;end
end
report.confirmation_calls=0;report.deadline_observations=0;
if strcmp(lock.decision,'GO')
    fixed=jsondecode(fileread(fullfile(out,'fixed','journal_audit.json')));
    timed=jsondecode(fileread(fullfile(out,'timed','journal_audit.json')));
    assert(fixed.calls==1152 && timed.calls==7200 && isequal(fixed.process_ids,timed.process_ids))
    report.confirmation_calls=fixed.calls+timed.calls;report.deadline_observations=2*timed.calls;
end
report.figures=height(readtable(fullfile(out,'output','figures','verification.csv')));
writeJson(fullfile(out,'replay_status.json'),report)
end

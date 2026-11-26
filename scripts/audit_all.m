function audit_all(root)
%审核入口只读已经完成的会话，先核对真实字节再汇总区域和生成插图
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
addpath(genpath(fullfile(root,'src')),fullfile(root,'scripts'));
freezeExperiment(root,'verify');
run_analysis(root)
verify_results(root)
audit_missingness(root)
audit_events(root)
run_supplements(root)
run_region_summary(root)
run_quality_summary(root)
run_figures(root)
check_comments(root);
end

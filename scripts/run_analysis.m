function run_analysis(root)
[obs,events,runs]=readJournals(root);
manifest=readtable(fullfile(root,'data','manifests','frozen.csv'),'TextType','string');
[source,summary,coverage,paired,stability,loo,cat]=pairedStats(obs,manifest);
tables={obs,events,runs,source,summary,coverage,paired,stability,loo,cat};
names=["observations","events","runs","source_pairs","summary","coverage","paired_coverage", ...
    "session_summary","leave_one_source","category_sensitivity"];
for n=1:numel(tables),writetable(tables{n},fullfile(root,'results',names(n)+".csv"));end
fail=runs.status~="success";
writetable(runs(fail,:),fullfile(root,'results','terminal_failures.csv'))
[G,domain,method,deadline,budget,status]=findgroups(obs.dataset,obs.method,obs.deadline,obs.budget,obs.status);
count=splitapply(@numel,obs.rep,G);
writetable(table(domain,method,deadline,budget,status,count),fullfile(root,'results','status_counts.csv'))
end


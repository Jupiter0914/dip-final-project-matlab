function summary=profileDevelopment(implementation,label)
%剖析只使用冻结的开发名单，耗时只用于解释瓶颈
if nargin<1, implementation="reference"; end
if nargin<2, label=implementation; end
root=fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(genpath(fullfile(root,'src')));
addpath(fullfile(root,'performance','validation'));
assert(isfile(fullfile(root,'docs','optimization_plan.md')) && maxNumCompThreads==1);
T=readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
assert(height(T)==36 && all(T.official=="trainval"));
if implementation=="reference"
    encoder=@measureEncoding;
    stamp=struct('reference_entry',string(sha256Bytes(readBytes(which('measureEncoding')))));
else
    stamp=validationKernel(root,label); encoder=@efMeasure;
end
methods=["within_full","cross","matlab_geom","matlab_geom_within"];
inputs=cell(height(T),1);
for i=1:height(T), inputs{i}=readFrozenMask(root,T(i,:)); end
warm=inputs{T.id=="Bengal_187"}; out=fullfile(root,'perf_results','profiling',label);
if ~isfolder(out),mkdir(out);end
writeJson(fullfile(out,'kernel_stamp.json'),stamp);
for method=methods
    [trial,~]=encoder(warm,256,char(method),Inf,8);
    assert(~strcmp(trial.status,'program_error'),trial.reason);
end
calls=cell(height(T)*numel(methods),12); z=0;
profile clear
profile on
for i=1:height(T)
    for m=1:numel(methods)
        method=methods(m); before=memory; started=tic;
        [t,e]=encoder(inputs{i},256,char(method),Inf,8); returned=toc(started)*1000;
        after=memory; assert(~strcmp(t.status,'program_error'),t.reason);
        first=NaN; last=NaN; if ~isempty(e),first=e(1).received_ms; last=e(end).received_ms; end
        z=z+1; calls(z,:)={T.id(i),method,string(t.status),t.rings,numel(t.rounds),numel(e), ...
            first,last,t.end_ms,returned,before.MemUsedMATLAB,after.MemUsedMATLAB};
    end
end
profile off
p=profile('info'); F=p.FunctionTable;
rows=cell(0,6); lines=cell(0,4);
for i=1:numel(F)
    f=F(i); paths=replace(string(f.FileName),"\","/");
    project=replace(string(root),"\","/")+"/";
    if ~startsWith(paths,project,'IgnoreCase',true), continue; end
    name=extractAfter(paths,strlength(project));
    child=0;if ~isempty(f.Children),child=sum([f.Children.TotalTime]);end
    rows(end+1,:)={string(f.FunctionName),name,f.NumCalls,f.TotalTime,f.TotalTime-child,child};
    for j=1:size(f.ExecutedLines,1)
        v=f.ExecutedLines(j,:); lines(end+1,:)={string(f.FunctionName),v(1),v(2),v(3)};
    end
end
functions=cell2table(rows,'VariableNames',{'function_name','file','calls','inclusive_s','self_s','children_s'});
functions=sortrows(functions,'self_s','descend'); writetable(functions,fullfile(out,'functions.csv'));
writetable(cell2table(lines,'VariableNames',{'function_name','line','calls','time_s'}),fullfile(out,'lines.csv'));
trials=cell2table(calls,'VariableNames',{'id','method','status','rings','rounds','events','first_ms','last_ms', ...
    'end_ms','return_ms','pre_memory_bytes','post_memory_bytes'}); writetable(trials,fullfile(out,'calls.csv'));
summary=struct('implementation',implementation,'sources',height(T),'calls',height(trials),'total_rounds',sum(trials.rounds), ...
    'total_profiled_return_s',sum(trials.return_ms)/1000,'memory_min_bytes',min(trials.pre_memory_bytes), ...
    'memory_max_bytes',max(trials.post_memory_bytes),'version',version,'threads',maxNumCompThreads);
writeJson(fullfile(out,'summary.json'),summary); disp(summary);
end

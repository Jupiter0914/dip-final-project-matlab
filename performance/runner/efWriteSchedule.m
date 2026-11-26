function efWriteSchedule(root,action)
%在任何正式调用之前枚举全部位置，离线重放时重新生成并逐键复核
roster=readtable(fullfile(root,'data','manifests','exact_fast','exact_fast_confirm.csv'),'TextType','string');
values=cell(8352,8);n=0;
for session=1:3
    for stage=["timed","fixed"]
        src=roster;if stage=="fixed",src=src(logical(src.fixed48),:);end
        methods=efMethods(stage);
        for rep=1:2
            jobs=efSchedule(src,methods,stage,session,rep);
            for j=1:height(jobs)
                row=src(jobs.row(j),:);order=jobs.methods{j};
                for k=1:numel(order)
                    n=n+1;values(n,:)={stage,session,rep,j,k,row.dataset,row.id,order(k)};
                end
            end
        end
    end
end
assert(n==8352)
expected=cell2table(values,'VariableNames',{'grid','session','rep','block','position','dataset','id','method'});
path=fullfile(root,'performance','sampling','confirm_order.csv');
if strcmp(action,'create')
    assert(~isfile(path),'DIP:ScheduleExists','A prospective schedule already exists')
    writetable(expected,path)
else
    actual=readtable(path,'TextType','string');assert(isequal(expected,actual),'DIP:Schedule','Frozen sequence does not reproduce')
end
end

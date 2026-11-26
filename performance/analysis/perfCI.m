function ci=perfCI(v)
%每项统计用源重抽，区间顺序为百分之九十五下/上限、百分之九十七点五下/上限
v=double(v(:));assert(all(isfinite(v)));ci=nan(1,4);if isempty(v),return;end
stream=RandStream('mt19937ar','Seed',40121);n=numel(v);ix=randi(stream,n,n,10000);
m=mean(reshape(v(ix),n,10000),1);ci=prctile(m,[2.5 97.5 1.25 98.75]);
end

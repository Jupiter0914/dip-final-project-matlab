function jobs = buildSchedule(cfg,rows,sid,rep)
%按源和预算分块，在六次测量间循环移动块内方法的顺序
methods = ["seed","within_full","cross","matlab_geom_within","matlab_geom"];
jobs = cell(0,4);
for i=1:height(rows)
    budgets = 256;
    if rows.supplement(i)
        budgets = [256 128 512];
    end
    for b=budgets
        list = methods;
        if rows.supplement(i) && b==256
            list(end+1) = "exact";
        end
        key = rows.dataset(i)+"/"+rows.id(i)+"|"+string(b);
        hashes = strings(size(list));
        for m=1:numel(list)
            hashes(m) = sha256Bytes(unicode2native(char(string(cfg.order_salt)+"|"+key+"|"+list(m)),'UTF-8'));
        end
        [~,ix] = sort(hashes);
        shift = mod((sid-1)*2+rep-1,numel(list));
        sorted = circshift(list(ix),-shift);
        block = string(sha256Bytes(unicode2native(char(string(cfg.order_salt)+"|"+string(sid)+"|"+string(rep)+"|"+key),'UTF-8')));
        jobs(end+1,:) = {block,i,b,sorted};
    end
end
[~,ix] = sort(string(jobs(:,1)));
jobs = jobs(ix,:);
end


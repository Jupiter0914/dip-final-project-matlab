function run_smoke(root)
%只用分配给开发的原始图检查独立起点、接收时钟和实际文件长度
dev = readtable(fullfile(root,'data','manifests','dev.csv'),'TextType','string');
samples = ["Bengal_187","american_pit_bull_terrier_148","Bengal_148"];
methods = ["seed","within_full","cross","matlab_geom","matlab_geom_within","exact"];
results = {};
for n=1:numel(samples)
    row = dev(dev.id==samples(n),:);
    raw = readFrozenMask(root,row);
    for pass=1:2
        order = 1:numel(methods);
        if pass==2,order=fliplr(order);end
        seeds = strings(size(methods));
        for m=order
            [trial,ev] = measureEncoding(raw,256,char(methods(m)),200,8);
            assert(~strcmp(trial.status,'program_error'),'dip:Smoke','%s',trial.reason)
            for k=1:numel(ev)
                score = pixelScores(raw,decodePM31(ev(k).bytes));
                assert(score.xor==ev(k).xor && ev(k).received_ms>=ev(k).serialized_ms)
            end
            if ~isempty(ev),seeds(m)=sha256Bytes(ev(1).bytes);end
            results(end+1,:) = {row.id,pass,methods(m),string(trial.status), ...
                trial.return_ms,trial.end_ms,numel(ev),seeds(m)};
        end
        assert(seeds(1)==seeds(2) && seeds(2)==seeds(3) && seeds(3)==seeds(6))
        assert(seeds(4)==seeds(5))
    end
end
T=cell2table(results,'VariableNames',{'id','pass','method','status','return_ms','end_ms','events','seed_sha'});
writetable(T,fullfile(root,'results','smoke.csv'))
end


function rows=exploreWithinControls(root,manifest,out)
%固定做两轮，测量候选强度，不设置时间截断
methods=["within_old","within_full_oldtri","within_full","cross_oldtri","cross_full_oldtri","cross"];
rows=struct([]);
for i=1:height(manifest)
    id=manifest.id(i); mask=readFrozenMask(root,manifest(i,:));
    for method=methods
        started=tic; prep=prepareMask(mask,256); [state,info]=allocationSeed(prep);
        rec=struct('id',id,'method',method,'rings',numel(prep.dense),'status',string(info.status), ...
            'reason',string(info.reason),'seed_xor',NaN,'final_xor',NaN,'bytes',0,'sha256',"", ...
            'eligible_pairs',0,'proposed_pairs',0,'rounds',0,'under24',0,'accepted',0, ...
            'across',0,'triangles',0,'full_checks',0,'elapsed_ms',NaN);
        if ~isempty(state)
            rec.seed_xor=state.d;
            for round=1:2
                [next,log]=exchangeStep(prep,state,char(method));
                rec.rounds=round; rec.eligible_pairs=rec.eligible_pairs+log.eligiblePairs;
                rec.proposed_pairs=rec.proposed_pairs+log.proposedPairs;
                rec.under24=rec.under24+(log.proposedPairs<24);
                rec.full_checks=rec.full_checks+log.fullChecks;
                if ~log.accepted, break; end
                rec.accepted=rec.accepted+1; rec.across=rec.across+log.cross;
                rec.triangles=rec.triangles+log.triangle; state=next;
            end
            b=packPM31(prep.shape,state.rings,prep.parents); rec.elapsed_ms=1000*toc(started);
            pred=decodePM31(b); assert(nnz(pred~=mask)==state.d);
            rec.final_xor=state.d; rec.bytes=numel(b); rec.sha256=string(sha256Bytes(b));
            path=fullfile(out,'control_blobs'); if ~isfolder(path), mkdir(path); end
            fid=fopen(fullfile(path,rec.sha256+".pm3"),'wb'); fwrite(fid,b,'uint8'); fclose(fid);
        else
            rec.elapsed_ms=1000*toc(started);
        end
        rows=[rows;rec];
    end
    writetable(struct2table(rows),fullfile(out,'within_candidate_controls.csv'));
end
end

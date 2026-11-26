function recs=exploreSingle(root,manifest,out)
%完整单圈对照在预先选定的三个开发源上使用两个点数
recs=struct([]);
methods=["rdp","grid_dp","full_dp","geometry","raster","local_iou","sm_iou","post_xor","post_guard"];
store=fullfile(out,'pol1'); if ~isfolder(store), mkdir(store); end
for i=1:height(manifest)
    raw=readFrozenMask(root,manifest(i,:)); id=manifest.id(i);
    for k=[16 32]
        for method=methods
            timer=tic; [target,dense]=pol1Exterior(raw);
            rec=struct('id',id,'k',k,'method',method,'status',"success",'reason',"", ...
                'outer_added',nnz(target & ~raw),'outer_removed',nnz(raw & ~target), ...
                'xor',NaN,'fp',NaN,'fn',NaN,'iou',NaN,'bf1',NaN,'bf2',NaN,'bf3',NaN, ...
                'bytes',0,'sha256',"",'proposals',0,'accepted',0,'bf2_rejected',0,'fallback',0,'encode_ms',NaN);
            try
                [p,log]=pol1Fit(target,dense,k,method);
                b=pol1Wire(size(target),p); rec.encode_ms=1000*toc(timer);
                [~,pred]=pol1Wire(size(target),p);
                rec.bytes=numel(b); rec.sha256=string(sha256Bytes(b));
                fid=fopen(fullfile(store,rec.sha256+".poly"),'wb'); fwrite(fid,b,'uint8'); fclose(fid);
                rec.fp=nnz(pred & ~target); rec.fn=nnz(target & ~pred); rec.xor=rec.fp+rec.fn;
                rec.iou=nnz(target & pred)/nnz(target | pred);
                rec.bf1=pol1BoundaryScore(target,pred,1); rec.bf2=pol1BoundaryScore(target,pred,2);
                rec.bf3=pol1BoundaryScore(target,pred,3); rec.proposals=log.proposals;
                rec.accepted=log.accepted; rec.bf2_rejected=log.rejectedBF2; rec.fallback=log.fallback;
            catch err
                if ~ismember(string(err.identifier),["DIP:BadOutline","DIP:NoFeasibleDeletion"]), rethrow(err); end
                rec.status="search_no_valid_output"; rec.reason=string(err.message); rec.encode_ms=1000*toc(timer);
            end
            recs=[recs;rec];
            writetable(struct2table(recs),fullfile(out,'poly02_trials.csv'));
        end
    end
end
end

function rows=explorePSO(root,manifest,out)
%运行作者原函数，固定源、固定预算、固定随机种子，保留所有尝试
archive=fullfile(root,'data','upf-author.zip');
if ~isfile(archive)
    url="https://addons.mathworks.com/downloads/9b/9bf0e77b-720e-422d-a51d-beee4b9483fe/1.0.0/unconstrained_polygonal_fitting-1.0.0.zip";
    websave(archive,url);
end
fid=fopen(archive,'rb'); guard=onCleanup(@() fclose(fid));
digest=sha256Bytes(fread(fid,Inf,'*uint8')); clear guard
assert(strcmp(digest,'67c9a9f527142f8e2e5f4cec7a8a2724930059ecb876cc678095dbc3a868c1bc'),'DIP:AuthorArchive','Author archive checksum differs')
external=tempname; mkdir(external); unzip(archive,external); addpath(external);
leave=onCleanup(@() cleanupAuthor(external));
ids=["pomeranian_10","pug_127","British_Shorthair_187"];
storage=fullfile(out,'pso'); if ~isfolder(storage), mkdir(storage); end
rows=struct([]);
for id=ids
    row=manifest(manifest.id==id,:); raw=readFrozenMask(root,row);
    [mask,~]=pol1Exterior(raw); s=regionprops(mask,'Area','Centroid');
    assert(isscalar(s),'Expected one exterior silhouette');
    for k=[8 16 32]
        for seed=[1703 2909 4231]
            rec=struct('id',id,'k',k,'seed',seed,'status',"search_no_valid_output", ...
                'reason',"",'solver_ms',NaN,'native_iou',NaN,'native_dice',NaN, ...
                'clipped_vertices',0,'bytes',0,'sha256',"",'xor',NaN,'iou',NaN);
            rng(seed,'twister'); timer=tic;
            sol=getPSO_EA_Coords(mask,s.Centroid,k,s.Area,1,0,0);
            rec.solver_ms=toc(timer)*1000; rec.native_iou=sol.IoU; rec.native_dice=sol.DICE;
            native=sol.p; integer=floor(native-1+0.5)+1;
            xy=min(fliplr(size(mask)),max(1,integer));
            stem=fullfile(storage,sprintf('%s-K%d-seed%d',id,k,seed));
            writematrix(native,stem+"-author.csv");
            rec.clipped_vertices=nnz(any(xy~=integer,2));
            reason=vectorCheck({xy},-1);
            if strcmp(reason,'ok')
                [bytes,pred]=pol1Wire(size(mask),xy);
                fid=fopen(stem+".poly",'wb'); fwrite(fid,bytes,'uint8'); fclose(fid);
                rec.bytes=numel(bytes); rec.sha256=string(sha256Bytes(bytes));
                rec.xor=nnz(mask~=pred); rec.iou=nnz(mask & pred)/nnz(mask | pred);
                rec.status="success";
            else
                rec.reason=string(reason);
            end
            rows=[rows;rec];
            writetable(struct2table(rows),fullfile(out,'pso_trials.csv'));
        end
    end
end
end

function cleanupAuthor(path)
rmpath(path);
rmdir(path,'s');
end

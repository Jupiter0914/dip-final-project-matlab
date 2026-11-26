function [p,log]=pol1Fit(mask,dense,k,method)
%所有局部目标共用半径、八方向和平局次序
radii=[8 4 2 1 4 2 1];
log=struct('fallback',0,'proposals',0,'accepted',0,'rejectedBF2',0);
if method=="sm_iou"
    [ids,log.fallback]=pol1Start(dense,min(size(dense,1),max(50,k+1)),"rdp");
    p=dense(ids,:);
    while size(p,1)>k
        choices=inf(size(p,1),1);
        for j=1:size(p,1)
            trial=p; trial(j,:)=[];
            pred=pol1Paint(size(mask),trial);
            choices(j)=-nnz(pred & mask)/nnz(pred | mask);
        end
        log.proposals=log.proposals+numel(choices);
        [~,order]=sort(choices); found=false;
        for j=order'
            trial=p; trial(j,:)=[];
            if strcmp(vectorCheck({trial},-1),'ok'), p=trial; found=true; break; end
        end
        if ~found, error('DIP:NoFeasibleDeletion','Sequential deletion has no admissible move'); end
        log.accepted=log.accepted+1;
    end
    return
end
[ids,log.fallback]=pol1Start(dense,k,method); p=dense(ids,:);
if ismember(method,["rdp","grid_dp","full_dp"]), return; end
passes=method;
if ismember(method,["post_guard","post_xor"]), passes=["geometry",method]; end
[xx,yy]=meshgrid(-1:1);
direction=[reshape(xx.',[],1),reshape(yy.',[],1)];
direction(all(direction==0,2),:)=[];
n=size(dense,1); sums=zeros(k,6); closed=[ids,n+1];
for i=1:k
    pts=dense(closed(i):closed(i+1)-1,:);
    x=pts(:,1); y=pts(:,2); sums(i,:)=[numel(x),sum(x),sum(y),x'*x,x'*y,y'*y];
end
for objective=passes
    pred=pol1Paint(size(mask),p);
    current=loss(mask,pred,objective);
    if objective=="post_guard", floorBF=pol1BoundaryScore(mask,pred,2); end
    for s=1:numel(radii)
        order=1:k; if mod(s,2)==0, order=fliplr(order); end
        for j=order
            origin=p(j,:); moves=origin+radii(s)*direction;
            moves=moves(all(moves>=1 & moves<=fliplr(size(mask)),2),:);
            costs=zeros(size(moves,1),1);
            if objective=="geometry"
                prev=mod(j-2,k)+1; next=mod(j,k)+1;
                current=arcLoss(sums(prev,:),p(prev,:),origin)+arcLoss(sums(j,:),origin,p(next,:));
                for i=1:size(moves,1)
                    costs(i)=arcLoss(sums(prev,:),p(prev,:),moves(i,:))+arcLoss(sums(j,:),moves(i,:),p(next,:));
                end
            else
                for i=1:size(moves,1)
                    p(j,:)=moves(i,:); costs(i)=loss(mask,pol1Paint(size(mask),p),objective);
                end
            end
            p(j,:)=origin; log.proposals=log.proposals+numel(costs);
            [~,rank]=sort(costs);
            for i=rank'
                threshold=1e-9*double(objective=="geometry");
                if costs(i)>=current-threshold, break; end
                p(j,:)=moves(i,:);
                if ~strcmp(vectorCheck({p},-1),'ok'), p(j,:)=origin; continue; end
                if objective=="post_guard" && pol1BoundaryScore(mask,pol1Paint(size(mask),p),2)<floorBF
                    log.rejectedBF2=log.rejectedBF2+1; p(j,:)=origin; continue
                end
                log.accepted=log.accepted+1; current=costs(i); break
            end
        end
    end
end
end

function val=loss(mask,pred,objective)
if objective=="local_iou", val=-nnz(mask & pred)/nnz(mask | pred);
else, val=nnz(mask~=pred); end
end

function e=arcLoss(stats,a,b)
d=b-a; nx=-d(2); ny=d(1); z=-nx*a(1)-ny*a(2); den=d*d';
if den==0, e=inf; return; end
e=max(0,stats*[z*z;2*z*nx;2*z*ny;nx*nx;2*nx*ny;ny*ny])/den;
end

function prep=prepareMask(raw,budget)
%表示支持范围和高精度回填先于预算判断，避免把表示错误当成预算不足
validateattributes(budget,{'numeric'},{'scalar','integer','nonnegative','finite'})
prep=struct('status','unsupported_representation','reason','','raw',[],'shape',size(raw), ...
    'dense',{{}},'parents',[],'refs',{{}},'reference',[],'target',NaN,'lowerBound',NaN,'highVertices',NaN);
if ~ismatrix(raw) || any(size(raw)==0) || any(size(raw)>16382) || numel(raw)>4000000
    prep.reason='outside_coordinate_or_implementation_canvas_limit'; return
end
if ~(islogical(raw) || isnumeric(raw)) || ~isreal(raw) || any(raw(:)~=0 & raw(:)~=1)
    prep.reason='expected_binary_samples'; return
end
prep.raw=logical(raw);
try
    [prep.dense,prep.parents]=extractRings(prep.raw);
catch err
    if ~any(strcmp(err.identifier,{'DIP:Unsupported','DIP:InvalidGeometry'}))
        rethrow(err)
    end
    prep.reason=err.message; return
end
high=false(size(raw)); prep.refs=cell(size(prep.dense));
for i=1:numel(prep.dense)
    prep.refs{i}=rasterRing(prep.shape,prep.dense{i});
    high=xor(high,prep.refs{i});
end
if ~isequal(high,prep.raw)
    prep.reason='full_precision_pixel_mismatch'; return
end
r=numel(prep.dense);
prep.highVertices=sum(cellfun(@(p)size(p,1),prep.dense));
prep.lowerBound=10+16*r;
if budget<prep.lowerBound
    prep.status='below_proved_lower_bound'; prep.reason='header+ring_metadata+three_vertices_per_ring'; return
end
prep.target=min(prep.highVertices,floor((budget-10-4*r)/4));
prep.reference=digitalLayout(prep.raw);
prep.status='success'; prep.reason='ok';
end

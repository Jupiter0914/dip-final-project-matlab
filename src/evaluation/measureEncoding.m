function [trial,events] = measureEncoding(raw,budget,method,maxMs,maxRounds)
%每次调用都从内存中的二值图重新构建轮廓和起点
clock = tic;
events = struct('bytes',{},'round',{},'xor',{},'nbytes',{},'serialized_ms',{},'received_ms',{}, ...
    'donor',{},'receiver',{},'deleted_x',{},'deleted_y',{},'inserted_x',{},'inserted_y',{});
try
    trial = search(@receive);
    returned = toc(clock)*1000;
catch err
    returned = toc(clock)*1000;
    reason = char(regexprep(string(err.message),'(?i)[A-Z]:[\\/][^\r\n''"]*','<local path>'));
    stack = struct('function',{},'line',{});
    for frame=1:numel(err.stack)
        stack(frame)=struct('function',err.stack(frame).name,'line',err.stack(frame).line);
    end
    trial = struct('status','program_error','reason',reason,'error_id',err.identifier,'stack',{stack}, ...
        'rings',NaN,'end_ms',returned,'init',[],'rounds',{{}});
end
trial.return_ms = returned;

    function receive(bytes,event)
        received = toc(clock)*1000;
        event.received_ms = received;
        event.bytes = bytes;
        events(end+1) = event;
    end

    function result = search(receiver)
        result = struct('status','','reason','','rings',NaN,'end_ms',NaN,'init',[],'rounds',{{}});
        allowed = {'seed','matlab_geom','matlab_geom_within','within_full','cross','exact', ...
            'within_old','within_full_oldtri','cross_oldtri','cross_full_oldtri'};
        if ~any(strcmp(method,allowed)), error('DIP:Method','Unknown encoder method'); end
        validateattributes(maxMs,{'numeric'},{'scalar','real','nonnegative','nonnan'})
        validateattributes(maxRounds,{'numeric'},{'scalar','integer','finite','nonnegative'})
        prep = prepareMask(raw,budget);
        result.status = char(prep.status);
        result.reason = char(prep.reason);
        if isfield(prep,'parents')
            result.rings = numel(prep.parents);
        end
        if ~strcmp(prep.status,'success')
            result.end_ms = toc(clock)*1000;
            return
        end
        if startsWith(method,'matlab_geom')
            [state,info] = geometrySeed(prep);
        else
            [state,info] = allocationSeed(prep);
        end
        result.init = info;
        result.status = char(info.status);
        result.reason = char(info.reason);
        if ~isempty(state)
            publish(state,0,[]);
            if ~ismember(string(method),["seed","matlab_geom"]) && ~isempty(state.rings)
                searchMode = method;
                if strcmp(method,'matlab_geom_within')
                    searchMode = 'within_full';
                end
                for roundId = 1:maxRounds
                    if toc(clock)*1000 > maxMs
                        break
                    end
                    [next,action] = exchangeStep(prep,state,searchMode);
                    result.rounds{end+1} = action;
                    if ~action.accepted
                        break
                    end
                    state = next;
                    publish(state,roundId,action);
                end
            end
        end
        result.end_ms = toc(clock)*1000;

        function publish(candidate,roundId,action)
            event = struct('bytes',uint8([]),'round',roundId,'xor',candidate.d, ...
                'nbytes',0,'serialized_ms',NaN,'received_ms',NaN,'donor',NaN,'receiver',NaN, ...
                'deleted_x',NaN,'deleted_y',NaN,'inserted_x',NaN,'inserted_y',NaN);
            if ~isempty(action)
                event.donor = action.donor;
                event.receiver = action.receiver;
                event.deleted_x = action.removed(1);
                event.deleted_y = action.removed(2);
                event.inserted_x = action.inserted(1);
                event.inserted_y = action.inserted(2);
            end
            bytes = packPM31(prep.shape,candidate.rings,prep.parents);
            event.serialized_ms = toc(clock)*1000;
            event.nbytes = numel(bytes);
            assert(event.nbytes <= budget,'dip:Budget','编码超出预算')
            receiver(bytes,event)
        end
    end
end

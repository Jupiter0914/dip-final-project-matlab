function reason = vectorCheck(rings,parents)
try
    computed = geometryTree(rings);
catch err
    if ~strcmp(err.identifier,'DIP:InvalidGeometry')
        rethrow(err)
    end
    reason=err.message;
    return
end
if isequal(computed(:),double(parents(:)))
    reason='ok';
else
    reason='nesting_changed';
end
end

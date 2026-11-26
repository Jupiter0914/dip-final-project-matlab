function [names,base]=efMethods(stage)
switch string(stage)
    case {"dev1","dev2"}
        names=["old_within","fast_within","old_cross","fast_cross","old_geom","fast_geom","old_geom_within","fast_geom_within"];
    case "timed"
        names=["old_within","fast_within","old_cross","fast_cross","fast_geom","fast_geom_within"];
    case "fixed"
        names=["old_within","fast_within","old_cross","fast_cross"];
    otherwise
        error('DIP:Stage','Unknown stage')
end
base=extractAfter(names,"_");
base(base=="within")="within_full";base(base=="geom")="matlab_geom";base(base=="geom_within")="matlab_geom_within";
end

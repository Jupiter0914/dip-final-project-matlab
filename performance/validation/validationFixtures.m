function [names,masks]=validationFixtures()
names=strings(520,1);masks=cell(520,1);
for i=0:511
    names(i+1)="pattern_"+i; masks{i+1}=reshape(logical(bitget(uint16(i),1:9)),3,3)';
end
labels=["empty","full","one_border_pixel","corner_touch","one_pixel_hole","island_in_hole","diagonal_neck","near_components"];
for j=1:numel(labels)
    m=false(13,14);
    switch labels(j)
        case "full", m(:)=true;
        case "one_border_pixel", m(1,1)=true;
        case "corner_touch",m(7,8)=true;m(8,9)=true;
        case "one_pixel_hole",m(2:12,2:13)=true;m(6,7)=false;
        case "island_in_hole",m(2:end-1,2:end-1)=true;m(4:end-3,4:end-3)=false;m(6:end-5,6:end-5)=true;
        case "diagonal_neck",m(2:5,2:5)=true;m(9:12,10:13)=true;m(sub2ind(size(m),5:9,6:10))=true;
        case "near_components",m(3:11,2:6)=true;m(3:11,9:13)=true;
    end
    names(512+j)=labels(j);masks{512+j}=m;
end
end

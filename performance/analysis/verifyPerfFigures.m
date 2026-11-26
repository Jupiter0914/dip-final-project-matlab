function verifyPerfFigures(figdir,names)
%从文件读出记录的物理分辨率，检查SVG含实际绘制的矢量元素
manifest=cell(numel(names),7);
factory=javax.xml.parsers.DocumentBuilderFactory.newInstance;factory.setNamespaceAware(true);
factory.setFeature('http://apache.org/xml/features/nonvalidating/load-external-dtd',false);
factory.setFeature('http://xml.org/sax/features/external-general-entities',false);
factory.setFeature('http://xml.org/sax/features/external-parameter-entities',false);
parser=factory.newDocumentBuilder();ns='http://www.w3.org/2000/svg';
for i=1:numel(names)
    file=fullfile(figdir,names(i));png=readBytes(file+".png");info=imfinfo(file+".png");dpi=[NaN NaN];idx=9;
    while idx+11<=numel(png)
        n=double(png(idx:idx+3))*[2^24;2^16;2^8;1];
        if strcmp(char(png(idx+4:idx+7)),'pHYs')&&n==9&&png(idx+16)==1
            dpi=double(reshape(png(idx+8:idx+15),4,2)).'*[2^24;2^16;2^8;1]*.0254;break
        end
        idx=idx+12+n;
    end
    assert(all(dpi>=300));doc=parser.parse(java.io.File(char(file+".svg")));node=doc.getDocumentElement();assert(strcmp(node.getNamespaceURI(),ns));
    nodes=node.getElementsByTagNameNS(ns,'*');count=0;
    for j=0:nodes.getLength()-1
        item=nodes.item(j);tag=string(char(item.getLocalName()));
        if ~ismember(tag,["text","path","line","polyline","polygon","circle"]),continue;end
        parent=item.getParentNode();visible=true;
        while parent.getNodeType()==1
            if ismember(string(char(parent.getLocalName())),["defs","clipPath","mask"]),visible=false;break;end
            parent=parent.getParentNode();
        end
        count=count+visible;
    end
    assert(count>=3);manifest(i,:)={names(i),info.Width,info.Height,dpi(1),dpi(2),count,string(sha256Bytes(readBytes(file+".svg")))};
end
writetable(cell2table(manifest,'VariableNames',{'figure','width','height','dpi_x','dpi_y','visible_vectors','svg_sha256'}),fullfile(figdir,'figure_verification.csv'));
end

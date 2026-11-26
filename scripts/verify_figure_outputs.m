function verify_figure_outputs(root)
%独立重读导出图像、真实字节及裁片来源，检查交付文件没有写错或截断
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
addpath(genpath(fullfile(root,'src')));folder=fullfile(root,'figures');data=fullfile(folder,'data');
index=readtable(fullfile(root,'figures','figure_manifest.csv'),'TextType','string');
assert(height(index)==7 && numel(unique(index.id))==7);checks=cell(height(index),10);
for k=1:height(index)
    unit=index(k,:);checks(k,:)={unit.id,unit.status,NaN,NaN,NaN,NaN,NaN,NaN,"",""};
    if ~startsWith(unit.status,"generated"),continue;end
    png=fullfile(root,unit.png);svg=fullfile(root,unit.svg);meta=imfinfo(png);
    %物理分辨率直接读PNG的单位长度字段，避免不同平台的元数据字段名称差别
    bytes=readBytes(png);idx=9;dpi=[NaN NaN];
    while idx+11<=numel(bytes)
        lengthField=double(bytes(idx:idx+3))*[2^24;2^16;2^8;1];
        if strcmp(char(bytes(idx+4:idx+7)),'pHYs') && lengthField==9 && bytes(idx+16)==1
            dpi=double(reshape(bytes(idx+8:idx+15),4,2)).'*[2^24;2^16;2^8;1]*.0254;break
        end
        idx=idx+12+lengthField;
    end
    assert(meta.Width>700 && meta.Height>500 && all(dpi>=300),'DIP:FigureResolution','Insufficient resolution: %s',unit.id);
    [vectors,embedded]=inspectSvg(svg);
    expected=0;
    if unit.id=="01-encoding",trace=readtable(fullfile(data,'01-encoding.csv'));expected=1+any(trace.received_ms<=100);
    elseif unit.id=="02-exchange",expected=4;elseif unit.id=="05-structure",expected=2;
    elseif unit.id=="06-cases",chosen=readtable(fullfile(data,'06-cases.csv'));expected=3*height(chosen);end
    assert(vectors>=3 && embedded==expected,'DIP:FigureSVG','Vector paths or embedded case panels differ for %s',unit.id);
    checks(k,:)={unit.id,unit.status,meta.Width,meta.Height,dpi(1),dpi(2),vectors,embedded,sha256Bytes(readBytes(png)),sha256Bytes(readBytes(svg))};
end
t=cell2table(checks,'VariableNames',{'figure','status','width','height','horizontal_dpi','vertical_dpi','visible_vector_elements','embedded_png_panels','png_sha256','svg_sha256'});
writetable(t,fullfile(root,'figures','figure_verification.csv'));
if any(index.id=="02-exchange" & index.status=="generated")
    x=readtable(fullfile(data,'02-exchange.csv'),'TextType','string');
    old=verifyCase(fullfile(data,'case02'),'before',x(1,:));
    new=verifyCase(fullfile(data,'case02'),'after',x(2,:));assert(nnz(old~=new)>0 && x.xor(1)>x.xor(2) && x.nbytes(1)==x.nbytes(2));
end
if any(index.id=="05-structure" & index.status=="generated")
    x=readtable(fullfile(data,'05-hole.csv'),'TextType','string');new=verifyCase(fullfile(data,'case05'),'cross',x);
    old=imread(fullfile(data,'case05','input.png'))~=0;ref=digitalLayout(old);out=digitalLayout(new);
    a=ref.bg==x.reference_label;b=out.bg==x.decoded_label;
    assert(nnz(a)==x.reference_area && nnz(b)==x.decoded_area && nnz(a&b)==x.overlap,'DIP:HoleAudit','Matched hole areas disagree');
end
if any(index.id=="06-cases" & startsWith(index.status,"generated"))
    x=readtable(fullfile(data,'06-cases.csv'),'TextType','string');
    for k=1:height(x)
        for method=["within_full","cross"]
            if method=="cross",suffix="_cross";else,suffix="_base";end
            row=table(x.("sha256"+suffix)(k),x.("nbytes"+suffix)(k),x.("xor"+suffix)(k),'VariableNames',{'sha256','nbytes','xor'});
            verifyCase(fullfile(data,"case06-"+x.figure_column(k)),method,row);
        end
    end
end
end

function decoded=verifyCase(path,tag,row)
bytes=readBytes(fullfile(path,string(tag)+".pm3"));assert(numel(bytes)==row.nbytes && sha256Bytes(bytes)==string(row.sha256));
decoded=decodePM31(bytes);truth=imread(fullfile(path,'input.png'))~=0;saved=imread(fullfile(path,string(tag)+"-decoded.png"))~=0;
assert(isequal(decoded,saved) && nnz(decoded~=truth)==row.xor,'DIP:CaseReplay','Saved reconstructed mask or XOR differs');
rgb=imread(fullfile(path,string(tag)+"-errors.png"));
fp=rgb(:,:,1)==218 & rgb(:,:,2)==111 & rgb(:,:,3)==40;fn=rgb(:,:,1)==45 & rgb(:,:,2)==117 & rgb(:,:,3)==171;
assert(isequal(fp,decoded & ~truth) && isequal(fn,~decoded & truth),'DIP:ErrorColours','Marked FP or FN differs from decoded pixels');
end

function [vectors,embedded]=inspectSvg(file)
%按XML命名空间解析，结束标签可以在名称和尖括号之间换行
factory=javax.xml.parsers.DocumentBuilderFactory.newInstance;
factory.setNamespaceAware(true);
factory.setFeature('http://apache.org/xml/features/nonvalidating/load-external-dtd',false);
factory.setFeature('http://xml.org/sax/features/external-general-entities',false);
factory.setFeature('http://xml.org/sax/features/external-parameter-entities',false);
builder=factory.newDocumentBuilder();doc=builder.parse(java.io.File(char(file)));
root=doc.getDocumentElement();ns='http://www.w3.org/2000/svg';
assert(strcmp(char(root.getLocalName()),'svg') && strcmp(char(root.getNamespaceURI()),ns),'DIP:FigureSVG','Unexpected root namespace');
vectors=0;embedded=0;nodes=root.getElementsByTagNameNS(ns,'*');
for k=0:nodes.getLength()-1
    elem=nodes.item(k);name=string(char(elem.getLocalName()));
    href=string(char(elem.getAttributeNS('http://www.w3.org/1999/xlink','href')));
    if strlength(href)==0,href=string(char(elem.getAttribute('href')));end
    if strlength(href)>0
        assert(startsWith(href,"#") || startsWith(href,"data:image/png;base64,"),'DIP:FigureDependency','SVG has an external resource');
    end
    if name=="image"
        assert(startsWith(href,"data:image/png;base64,"),'DIP:FigureDependency','Missing embedded pixel panel');
        embedded=embedded+1;continue
    end
    if ~ismember(name,["path","line","circle","polyline","polygon","text"]),continue;end
    if name=="path" && isempty(char(elem.getAttribute('d'))),continue;end
    parent=elem.getParentNode();visible=true;
    while parent.getNodeType()==1
        if ismember(string(char(parent.getLocalName())),["defs","clipPath","mask","symbol"])
            visible=false;break
        end
        parent=parent.getParentNode();
    end
    vectors=vectors+visible;
end
end

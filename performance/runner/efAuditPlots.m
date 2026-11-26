function efAuditPlots(root,formal)
%从最终导出文件独立核对图片像素尺寸、物理分辨率和矢量内容
folder=fullfile(root,'perf_results','output','figures');files=dir(fullfile(folder,'*.png'));
if formal,assert(numel(files)>=5);else,assert(numel(files)>=3);end
result=cell(numel(files),7);
for k=1:numel(files)
    [~,id]=fileparts(files(k).name);png=fullfile(folder,files(k).name);svg=fullfile(folder,[id '.svg']);
    meta=imfinfo(png); pix=imread(png);assert(meta.Width>=700 && meta.Height>=450 && max(pix(:))>min(pix(:)))
    bytes=readBytes(png);cursor=9;dpi=[NaN NaN];
    while cursor+11<=numel(bytes)
        len=double(bytes(cursor:cursor+3))*[2^24;2^16;2^8;1];
        if strcmp(char(bytes(cursor+4:cursor+7)),'pHYs') && len==9 && bytes(cursor+16)==1
            dpi=double(reshape(bytes(cursor+8:cursor+15),4,2)).'*[2^24;2^16;2^8;1]*.0254;break
        end
        cursor=cursor+12+len;
    end
    assert(all(dpi>=299.9))
    factory=javax.xml.parsers.DocumentBuilderFactory.newInstance();factory.setNamespaceAware(true);
    factory.setFeature('http://apache.org/xml/features/nonvalidating/load-external-dtd',false);
    parser=factory.newDocumentBuilder();doc=parser.parse(java.io.File(char(svg)));
    nodes=doc.getElementsByTagNameNS('*','*'); count=0;
    for j=0:nodes.getLength()-1
        name=string(nodes.item(j).getLocalName());
        count=count+ismember(name,["line","path","polygon","polyline","circle","rect","text"]);
    end
    assert(count>=3)
    result(k,:)={string(id),meta.Width,meta.Height,min(dpi),count,string(sha256Bytes(readBytes(png))),string(sha256Bytes(readBytes(svg)))};
end
writetable(cell2table(result,'VariableNames',{'figure','width','height','dpi','vector_nodes','png_sha256','svg_sha256'}),fullfile(folder,'verification.csv'))
end

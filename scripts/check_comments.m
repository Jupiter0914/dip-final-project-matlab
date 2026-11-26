function count=check_comments(root)
%通过语法树识别真正的注释，避开字符串中的百分号
files=dir(fullfile(root,'**','*.m')); count=0;
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name);
    if contains(path,[filesep 'local' filesep]),continue;end
    tree=mtree(path,'-file','-comments');
    parseErrors=tree.mtfind('Kind','ERR');
    assert(isempty(indices(parseErrors)),'dip:Syntax','MATLAB 语法树报告错误 %s',path)
    comments=tree.mtfind('Kind','COMMENT');
    words=comments.strings;
    for j=1:numel(words)
        c=words{j}; count=count+1;
        assert(~isempty(regexp(c,'^%[^\s%]','once')) && isempty(regexp(strtrim(c),'[。.]+$','once')) ...
            && ~isempty(regexp(c,'[\x{3400}-\x{9fff}]','once')),'dip:Comment','注释格式有误 %s %s',path,c)
    end
end
fprintf('%d 条注释已核对\n',count)
end


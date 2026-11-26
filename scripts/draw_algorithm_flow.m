function draw_algorithm_flow(folder)
%分支标明验收失败和循环终止，检查点的交付发生在编码函数返回之前
if nargin==0
    folder=fullfile(fileparts(fileparts(mfilename('fullpath'))),'figures');
end
if ~isfolder(folder), mkdir(folder); end
f=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 20 22]);
guard=onCleanup(@() close(f));
ax=axes(f,'Position',[0.015 0.015 0.97 0.96],'XLim',[0 100],'YLim',[0 100],'Visible','off');
hold(ax,'on');
ink=[0.12 0.21 0.25]; teal=[0.01 0.36 0.38]; amber=[0.61 0.31 0.09];
text(ax,2,98,'完整二值蒙版的限时多边形编码','Color',ink,'FontName','SimSun','FontSize',17,'FontWeight','bold');
route([40 91;40 86],teal)
route([40 79;40 75],teal)
route([40 68;40 63],teal)
route([62 71.5;82 71.5;82 63],amber)
route([40 56;40 52],teal)
route([40 45;40 41],teal)
route([62 48.5;83 48.5;83 28],amber)
route([40 34;40 30],teal)
route([62 26.5;72 26.5],amber)
route([40 23;40 17],teal)
route([16 13.5;5 13.5;5 48.5;18 48.5],teal)
route([83 23;83 17],ink)
node(40,91.5,43,6,'内存中的原尺寸二值蒙版',false)
node(40,82.5,56,7,'提取轮廓、无损核对、计算预算并寻找起点',false)
node(40,71.5,44,8,'得到通过结构验收的起点？',true)
node(82,59.5,26,7,'记录原因并返回',false)
node(40,59.5,48,7,'序列化合格起点，同步交付完整文件',false)
node(40,48.5,44,8,'还有轮次及搜索时间？',true)
node(40,37.5,58,7,'逐圈评分，预排前24对删插，重新合成整图',false)
node(40,26.5,44,8,'本轮有少错且结构合法的候选？',true)
node(40,13.5,48,7,'接受调整，序列化并同步交付',false)
node(83,26.5,22,7,'结束搜索',false)
node(83,13.5,27,7,'返回调用方',false)
txt(66,73.3,'否');txt(42,66.2,'是');txt(66,50.5,'否');txt(42,42.8,'是');
txt(66,28.4,'否');txt(42,20.6,'是');txt(6.5,29,'下一轮');
text(ax,3,4,'接收端在每次回调入口立即记时，截止时取已收到的最后一份合法文件','FontName','SimSun','FontSize',10,'Color',teal);
print(f,fullfile(folder,'algorithm-flow.png'),'-dpng','-r320');
print(f,fullfile(folder,'algorithm-flow.svg'),'-dsvg','-painters');
    function node(x,y,w,h,label,decision)
        if decision
            xx=x+[-w/2 0 w/2 0]; yy=y+[0 h/2 0 -h/2]; fill=[0.89 0.96 0.95];
        else
            xx=x+[-w/2 -w/2 w/2 w/2]; yy=y+[-h/2 h/2 h/2 -h/2]; fill=[0.96 0.97 0.97];
        end
        patch(ax,xx,yy,fill,'EdgeColor',teal,'LineWidth',1.0);
        text(ax,x,y,label,'HorizontalAlignment','center','FontName','SimSun','FontSize',10,'Color',ink);
    end
    function route(p,c)
        plot(ax,p(:,1),p(:,2),'Color',c,'LineWidth',1.1);
        v=p(end,:)-p(end-1,:);v=v/norm(v);u=[-v(2) v(1)];
        arrow=[p(end,:);p(end,:)-v*1.5+u*.7;p(end,:)-v*1.5-u*.7];
        patch(ax,arrow(:,1),arrow(:,2),c,'EdgeColor','none');
    end
    function txt(x,y,s)
        text(ax,x,y,s,'FontName','SimSun','Color',ink,'FontSize',9);
    end
end

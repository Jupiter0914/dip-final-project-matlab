function varargout = dip(action,varargin)
%从仓库根目录设置模块路径并选择运行入口
root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root,'src')),fullfile(root,'scripts'),fullfile(root,'tests'));
switch string(action)
    case "test"
        suite = runtests(fullfile(root,'tests'),'IncludeSubfolders',true);
        disp(table(suite))
        if isempty(suite) || ~all([suite.Passed])
            error('dip:TestsFailed','有测试未通过，检查测试日志')
        end
    case "smoke"
        run_smoke(root)
    case "confirm"
        run_confirm(root,varargin{:})
    case "analysis"
        run_analysis(root)
    case "figures"
        run_figures(root)
    case "supplements"
        run_supplements(root)
    case "verify"
        verify_results(root)
    case "freeze"
        freezeExperiment(root,'create')
    case "encode"
        [varargout{1:nargout}] = measureEncoding(varargin{:});
    otherwise
        error('dip:Action','未知入口 %s',action)
end
end


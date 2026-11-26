# 精确评价实验

参考入口为 src/evaluation/measureEncoding.m，快速入口为 performance/kernel/efMeasure.m。两者接收相同参数，单次调用的缓存只在该次搜索中使用。

## 运行

在具有原始会话 JSONL 和实际 PM31 的工程根目录用 PowerShell 运行 `./performance/run.ps1 replay`。需要 MATLAB R2024a 和 Image Processing Toolbox。命令从实际保存的字节重新解码，用调用方接收日志重算配对、工程门槛及本轮适用的统计和图，并复核已存的等价性证据。无需运行编码搜索。

完整重新执行使用 `./performance/run.ps1 fresh`。可通过 `-Destination` 提供尚不存在的目录，已有完成文件会保留。独立工作目录用于生成全新的测时。数据恢复脚本从数据作者发布的归档按名单和 SHA-256 提取输入。固定工作量允许完成已定的8个试探轮并自然停止，不能用于倒算100 ms文件。fresh 在本机重新计算工程门槛，门槛或选定版本的路径和历史不同时会记录本机结果，可开展的确认工作取决于已冻结的版本与名单。

## 审核路线

1. docs/optimization_plan.md 是观察新性能前保存的投入门槛。performance/reference/files.csv 用于核验参照身份。单线程进程在 runner/efSetup.m 核对方法解析路径。
2. profile/profileDevelopment.m 记录开发 Profiler 的调用、行和包含/独占耗时。普通工程与正式测量关闭 Profiler。kernel 只承担快速算法，validation 独立构造参考评价并保留逐项差异。
3. perf_results/dev*/ 下的调用、每次实收、同轮文件、来源配对和首份/总耗时用于工程判定。各次计时 JSONL 以会话/重复分开，实际文件按 SHA-256 存于 local/perf/blobs。原300的回归键和收据在 perf_results/old300。它们只用于等价性。
4. perf_results/output/figures 包含 MATLAB 绘制的缓存流程、剖析及本次适用的效果图；图的数据随图保存。开发停止时新确认网格不启用。正式确认如开展，统计材料位于 perf_results/output，包含实际覆盖、不同码长、未及时及其他失败状态。
5. docs/optimization_results.md 给出本轮研究判断和限制。基础实验与加速实验的关系见仓库首页。

perf_results/dev1-fixture_replay 是第一候选的合成文件归档自检，重复使用原520个夹具。它不增加独立开发源数，也不进入任何工程或确认估计。calls.csv 中的 memory_before、memory_after 是 MATLAB 进程快照，write_ms 测量本次输出寻址与落盘，JSONL 日志追加位于该数字之后。fallback_calls 在具备精确改边分支的方法上记录实际回退次数，其余方法该列为空。

归档的两个主要终点另有独立原始日志复算。根目录运行 `matlab -singleCompThread -batch "addpath('perf_results/independent_audit');auditPrimary(pwd)"`，该入口从原始 JSONL 中自行选择实际到时文件并核对字节、等权来源统计和双侧区间。正式结论及六文件图表验证分别见 perf_results/output/formal_claims.json 和 perf_results/output/figures/verification.csv。图01–04为四类实测图，另有缓存流程图与开发等价性／会话图。

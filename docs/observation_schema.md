# 逐次证据与缺失值

每行由 dataset、id、session、rep、budget、method 确定，带时点的观察再加 deadline。每个会话有两个 JSONL，一个源预算块全部方法完成后落盘。程序错误保留异常标识、消息、函数与行号。在重复内，另一个方法不复用上一个方法生成的起点。

|文件|含义|
|---|---|
|results/sessions/S*/rep*.jsonl|原始调用、终态、初始化尝试、各轮决策、接收的完整字节 SHA 与序列化/接收时间|
|results/runs.csv|12,168 次调用的终态、搜索终止、实际返回、读入/写盘、方法次序|
|results/events.csv 与 local/blobs|每次实收文件（包括晚到），按 SHA 查找同一份二进制文件|
|results/observations.csv|按实际接收时间在100/200 ms 各选最后一份文件。成功行含实测码长、XOR、FP、FN、IoU、RMSE。未收到或失败行的码长、时间与质量为空|
|results/source_pairs.csv|源、时点、预算、比较方法级的等会话平均。n_pairs 为双方及时且同码长的重复数|
|results/summary.csv、session_summary.csv、leave_one_source.csv、category_sensitivity.csv|各范围的源数、重复对数、均值、中位数、胜平负、来源级区间、会话、留一源、外域留类及整类重抽|
|results/coverage.csv、paired_coverage.csv、status_counts.csv、terminal_failures.csv|所有预定输入的覆盖、差值、单侧成功、双侧失败、详细失败终态和截止状态|
|results/structural_cost.csv、allocation_attempts.csv、exact_screen.csv|同一层级银行的分配与结构拒绝代价，以及离线直接整图排序的诊断|
|results/regions.csv、blob_metrics.csv、accepted_transitions.csv|按原文件复算的局部对应、边界 F1、逐动作点位和真实错误变化|
|results/time_distributions.csv|各域、预算、方法的首次交付/返回等时长的中位数和高分位数，成功样本数另列|

`success` 有合法文件。预算不足用 `below_proved_lower_bound`，候选耗尽用 `search_no_valid_output`，实现支持范围外用 `unsupported_representation`，异常用 `program_error`。时点前无文件且调用尚未返回时为 `not_ready`。原始终态和时点状态分别存放。第零轮没有删点和插点，动作坐标为空。没有有效源的效应/区间、删除唯一源后得到的空总体、没有合法分配时的合法错分、缺失孔的局部记录都按实际分母留空。正式运行不对失败补零。

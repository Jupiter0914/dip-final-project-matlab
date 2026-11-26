# 统计、作图与重放

在仓库根目录设置 `addpath(genpath('performance'))`。开发源和统计小样本自检执行 `perfAnalysis(pwd,'test')`。已有工程判定时，`perfAnalysis(pwd,'no-go')` 只读取开发门槛、开发剖析和开发逐轮校验，生成工程实测图与带缓存失效分支的流程图。仅在新确认完成后执行 `perfAnalysis(pwd,'formal')`。

正式入口先核对200源限时网格与48源固定工作量网格、合法文件摘要及位于截点内的实收，再输出 `perf_results/output/` 下的表和 `figures/` 下的图。源均值均先平均会话内合格的重复，再平均有效会话。10,000次有放回重抽只抽源，MATLAB twister 种子40121；每项用同一种子，百分位为 1.25、2.5、97.5、98.75。主要时间比在对数空间平均并取指数。固定工作量时长的非正/非有限值与低于一个计时刻度的正时长分别登记。本机每秒10,000,000个刻度，阈值为0.0001 ms；编码出的原始时间照常留存。平均少错定义为对照的 XOR 减被比较方法的 XOR。来自原研究的200张Oxford或100张LEMS不加入任何统计。

| 文件 | 内容 |
|---|---|
| fixed_pairs、fixed_by_source、fixed_summary、fixed_sessions | 每组是否可比、被排除的具体原因、同等工作量的总耗时/首份实收比、各结构层与各会话 |
| fixed_common_receipts、timed_common_receipts | 同一源、会话、重复、轮次的同字节实收以及相邻轮次的时间间隔。用于解释程序运行，受重复测量影响；图中的按轮中位不充当源级区间 |
| timed_observations、timed_failures_and_success | 两个截止时点各自选取的最后一份已收字节，其原尺寸错分、FP、FN、IoU和RMSE。原调用保留最终状态，失败不填零 |
| timed_pairs、timed_by_source、timed_quality、timed_sessions、timed_leave_one_out | 每组比较有独立分母，列其95%及97.5%区间、胜平负、中位、全六次子集与每删一个来源的均值。timed_pairs内 old_* 表示该行baseline文件，fast_* 表示该行method文件，真实方法名以这两列为准 |
| timed_coverage、four_cells、received_rounds | 全计划输入覆盖，双方成功、单方成功、双方失败、均及时异码长等计数；四格各自实际收到的轮次与总返回时间 |
| four_way_pairs、four_way_summary | 同次四方法都及时且真实长度相同的诊断人群。逐次列旧/快各自的机制差及两者之差。presence_code 的位权1、2、4、8依次是参考圈内、参考跨圈、快速圈内、快速跨圈 |
| formal_claims.json | 分开登记A、B判据及其区间；没有共同成功源时，相应质量结论不成立 |
| figures/、figures/cases/ | 实际图、绘图数据及案例的输入、独立解码、FP/FN图、原始PM31和记录键。案例中橙色为FP、蓝色为FN |

热点评价的计时开启了 MATLAB profiler，图中按属于项目的函数自身时间汇总，开发门槛测量关闭 profiler。两种时间不得合并。资源记录中的进程前后内存为瞬时值。

固定工作量的 `fixed_memory.csv` 为四种方法分别给出全体及逐会话的调用前、调用后 MiB 中位数和P95、最大实际快照以及前后变化。原始 `memory_before` 和 `memory_after` 来自同一 MATLAB 进程的 `MemUsedMATLAB`，含会话已分配、仍驻留的内存。两次快照没有观测到调用中任意时刻的峰值。`fixed_checkpoint_ratios.csv` 和 `timed_checkpoint_ratios.csv` 另列每轮累计实收时间与相邻轮间隔的来源均比和两档区间。

# 开发组剖析

MATLAB R2024a 24.1.0.2537033 以单计算线程运行。在 36 个登记 trainval 源上，各自执行 256 B 的圈内、跨圈、几何与几何后圈内方法，最多八轮、完整运行。每次调用独立生成种子。预先用 Bengal_187 各方法执行一次。剖析与工程计时使用不同进程，正式网格关闭 Profiler。下列时间用于定位对照源码中的开销；被调用函数时间包含在父函数内，各行不能相加。

| 参考实现中的操作 | 调用数 | 包含下层时间（秒） |
|---|---:|---:|
| 独立编码 | 144 | 81.823 |
| 完整联合删插步骤 | 794 | 74.523 |
| 单项、组合及前24名 | 794 | 58.130 |
| 单删完整回填评分行 | 47,234 | 22.590 |
| 单插完整回填评分行 | 68,021 | 32.975 |
| 联合操作后逐改动环的回填行 | 19,651 | 7.437 |
| 真正进入最终复查的调用行 | 754 | 5.516 |
| 总共调用的 rasterRing | 141,725 | 52.524 |
| 准备与无损检查 | 144 | 2.233 |
| 合法分配种子 | 72 | 3.589 |
| 几何基线种子 | 72 | 1.128 |
| 层级生成 / DP 与周长分配 | 118 / 72 | 0.146 / 0.092 |
| 连续几何树 / 数字区域布局 | 6,314 / 1,042 | 0.542 / 4.625 |
| PM31 序列化 / 接收回调 | 898 / 898 | 0.113 / 0.032 |

rasterRing 自身耗时 46.144 秒，另有 6.380 秒属于其下层函数。进程内围绕每次编码采样的 `memory.MemUsedMATLAB` 最低 2.350 GB、最高 2.584 GB（十进制 GB）。这两个数是调用边界观测值，不能给出单个候选的分配量或执行期间的瞬时峰值。剖析器、全部开发输入和 MATLAB 运行环境在进程中同时占用内存。每源的首份文件、末份文件、返回时刻、调用边界内存、每个函数及源代码行的实测值均保留。

热点集中于八连通填充后的删、插区域评分。第 1 轮以完整有序环作为缓存单位，同一环变动时全部相关单项失效。若开发门槛不足，应检查未变圈的实际复用计数，并优先考虑在原全局坐标中减少单项求值的像素工作量。

```powershell
matlab -singleCompThread -batch "addpath('performance/profile'); profileDevelopment('reference','reference')"
```

[逐次剖析记录](../perf_results/profiling/reference/calls.csv) · [函数耗时](../perf_results/profiling/reference/functions.csv) · [逐行耗时](../perf_results/profiling/reference/lines.csv) · [运行摘要](../perf_results/profiling/reference/summary.json)


## 第一轮环级缓存

在归档快照 performance/versions/v1 上重复相同的 36 源、144 调用和 794 轮剖析。累计编码返回时间为 78.217 秒。rasterRing 仍被调用 135,015 次（参考 141,725 次），包含耗时 50.869 秒、独占 44.791 秒。efCandidates 的 55.384 秒中，逐环 scoreOne 占 54.902 秒。完整复查 898 次、6.450 秒，准备 2.222 秒。调用边界内存读数为 2.581–2.666 GB。两次独立 Profiler 运行有各自的采样扰动，工程门槛只使用关闭 Profiler 的多进程数据。热点仍集中在需要重算环的局部删插提案，未变环的缓存只能消除其中一部分。[第一轮逐次数据](../perf_results/profiling/dev1/calls.csv) · [第一轮函数表](../perf_results/profiling/dev1/functions.csv) · [第一轮代码行表](../perf_results/profiling/dev1/lines.csv)


## 最终锁定实现

工程门槛通过后，按 selected_kernel.json 的逐文件摘要加载最后快版，以同一单线程、同一 36 源与四种方法重新剖析。共 144 个调用、794 轮。被剖析调用累计 27.006 秒。完整 rasterRing 调用从参考的 141,725 次降到 26,470 次，包含耗时 9.405 秒，独占 8.219 秒。882 次 efSingleChanges 共用 3.164 秒，包含其中 1,764 次边事件生成的 1.084 秒。候选生成总耗时 4.582 秒，全图结构复查仍执行 898 次、6.050 秒。采样到的进程内存为 2.676–2.743 GB。逐源首文件与末文件时刻属于 Profiler 条件，主要速度比以单独的正式计时为准。[锁定快版函数表](../perf_results/profiling/selected/functions.csv) · [逐源调用](../perf_results/profiling/selected/calls.csv) · [逐行耗时](../perf_results/profiling/selected/lines.csv)

# 本轮测量环境

参考环境为 Windows 11 24H2、Intel Core Ultra 9 275HX（24 核）、物理内存 16,489,648,128 B，MATLAB R2024a 24.1.0.2537033，Image Processing Toolbox 24.1。预检实际运行原14个测试函数，全部通过。参考入口校验解析位置及原文件 SHA。每个新进程逐一登记 PID、version、maxNumCompThreads、启动耗时和预热实际轮数，Bengal_187 只用于预热。Windows 高精度计数器频率为10,000,000 Hz，名义刻度0.0001 ms。配对比值排除非正、不可测及小于一个刻度的读数，并保留排除原因。

Profiler 的包含时间可重叠，结果以开发热点表解释，工程门槛与正式观察使用关闭 Profiler 的接收/返回时钟。每次调用之前和返回后从 MATLAB memory 记录的 MemUsedMATLAB 是进程级边界快照，包含分配器复用与进程其他内存；它不能测得内核中的瞬时峰值，也不能精确分摊每个候选。读入和写盘时间另存。

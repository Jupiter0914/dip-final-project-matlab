# 实测环境

Windows NT 10.0.26100，PCWIN64，Intel Core Ultra 9 275HX。MATLAB 24.1.0.2537033 (R2024a)，Image Processing Toolbox 24.1。两项 license('test',…) 均返回 1。MATLAB memory 返回约 16.49×10^9 B 物理内存。默认 maxNumCompThreads=24；正式启动使用 -singleCompThread 并逐进程记录实际设置。matlab.unittest.TestCase、exportgraphics 均在本机。图形、二进制与实际计时分别通过实验运行日志核实。

受限环境首次启动在 settings errors_warnings 插件加载处退出，退出码 1。正常 Windows 用户许可证环境的 -batch 探针成功。首次探针并非编码计时样本。

系统版本标识 24H2、内核构建 26100。Windows 字体注册项核实宋体／新宋体为 simsun.ttc，Times New Roman 为 times.ttf。像素读取、区域标记、距离变换等使用 Image Processing Toolbox，百分位函数 prctile 位于 R2024a 自带的 matlab/datafun。哈希使用 MATLAB 随附 JVM 的 SHA-256。正式测量使用单个 MATLAB 进程和单计算线程。
系统查询记录为 Windows 11 家庭版中文版，CPU 24 个物理核、24 个逻辑处理器，物理内存 16,489,648,128 B，可见内存 16,103,172 KiB。

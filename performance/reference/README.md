# 参考编码器
参考计时调用 src/evaluation/measureEncoding.m。优化入口是 performance/kernel/efMeasure.m。两种实现分别从同一输入构造初始解。
files.csv 给出公开 src 源文件的 SHA-256 和 Git 对象摘要。efSetup 在加载时逐项核对。编码、几何、拓扑和计时源文件保留实测版本的字节。开发夹具验证脚本调整了一行注释。原始选定内核的清单保存在 performance/selected_kernel.json，当前源码的清单在 configs/published_kernel.json。

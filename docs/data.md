# 恢复实验输入

Windows PowerShell 使用系统自带的 tar.exe。从仓库根目录执行 `./scripts/restore_data.ps1 -DevelopmentOnly`，只恢复 data/manifests/dev.csv 登记的 36 个官方 trainval 标注。常规单元测试仅使用这些原图及仓库内的测试夹具。

`./scripts/restore_data.ps1` 另外恢复基础实验的 200 个 Oxford 和 100 个 LEMS 输入。加速实验的 200 个新来源见 data/manifests/exact_fast，单独由 performance/sampling/restorePerfInputs.m 恢复。正式名单用于复现实测；开展新比较时需重新冻结设计、采用另外的留出图像。

脚本优先使用本机的已校验文件。首次下载后把原包保存在 local。也可传入 `-OxfordArchive` 和 `-LemsArchive`，指定已取得的作者原包。Oxford 的 annotations.tar.gz 的 SHA-256 为 `52425fb6de5c424942b7626b428656fcbd798db970a937df61750c0f1d358e91`，LEMS 的 Datasets_LEMS_MPEG7.rar 为 `f6a132c16ca4800fc9cfbe3d469a086599aba67783448362c0bc2275bf7e6d1c`。每份提取的文件须通过清单中的原始字节校验；readFrozenMask 在读入时再次核对原尺寸和像素摘要。[Oxford](https://www.robots.ox.ac.uk/~vgg/data/pets/) · [LEMS](https://sites.google.com/site/costaspanagiotakis/research/unconstrained-polygonal-fitting)

## 源码和实测凭据

configs/recorded 保存两次正式测量使用的原始冻结清单。当前分发版的文件清单在 configs/freeze.json 和 performance/formal_lock.json，用于检查新检出的源码、名单及运行入口。公开说明、取数与制图脚本经过整理；编码算法、阈值、计时方法、正式成员名单和主要结果表保持实测内容。原始逐事件日志和完整二进制保存在本地归档。独立审核的结果与逐源记录见 [independent_audit](../perf_results/independent_audit)。

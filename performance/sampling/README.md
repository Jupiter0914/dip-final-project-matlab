# 新确认输入的隔离与排序

工程门槛通过后调用 `selectPerfSources(root,fullfile(root,'perf_results','dev1'))`（第二轮通过时用 dev2）。函数同时核对 decision.json 与 gate.csv，已有正式名单时拒绝覆盖。抓取官方原包并核验散列可以先做；选取、解包读取候选、保存新清单只在 GO 后执行。

官方标注 `annotations.tar.gz` 为19,173,078字节，SHA-256 `52425fb6de5c424942b7626b428656fcbd798db970a937df61750c0f1d358e91`，其中 `annotations/test.txt` 为 `a5454003774ffe01f4f322756d3ba5495bae21cb30bb217ab285dbfa2bef245c`。[官方标注](https://thor.robots.ox.ac.uk/datasets/pets/annotations.tar.gz)

历史版本 `df7db2f61565fc207708d58ff4112336e9a86805` 的 records/poly04/data-screening.csv 对全部已登记Oxford输入有3705行（3669 test及36已用trainval），这里的 oxford_historical_screen.csv 保留全部这些行。旧表的状态分为336个已知、200个已确认、85个触及排除族、20个同族非代表和3064个未中配额。原图谱已检查同照、变换、近重复及派生关系。另有372个Oxford已知派生视图，由 records/poly04/known-views.csv 保留父源及变换后的摘要。新抽样显式合并基础实验开发及确认表的身份与摘要。两表只保存旧输入筛查资料；没有新刻度性能、编码器错误或输出质量。

在官方 test 中只保留历史图谱中尚未抽中的家族代表，按整个未用家族排除历史源，同时检查原始文件和原尺寸行序二值摘要。互斥层优先级为 near、holes、components、simple。每层按 SHA-256(UTF-8(`43129|exact-fast-confirm-v1|Oxford|源ID`)) 升序取50个；已选成员用独立盐 `43129|exact-fast-fixed-v1|` 从每层取12个。清单保存主排序和子集排序全摘要。逐个独立核对官方原文件、前景标签1的像素、前8/背4布局和输入结构层。任何不符或配额不足都会停下并报告，不能按编码可行性或时限另补样本。

预备阶段的 MATLAB R2024a 单线程自检只读取36个已允许的官方 trainval 源。四类原分层在36/36源上和旧输入筛查相同，自检另验证不齐重复下的会话均值、来源等权、常数和空样本区间，以及随机种子复现。入口为 `perfAnalysis(pwd,'test')`。旧图谱为输入筛查而计算过哈希和结构，新的“未用”指未进入以往开发或确认编码比较，也不属于禁止家族。

选样同时保存官方 `annotations/test.txt` 原字节于 `data/manifests/exact_fast/exact_fast_official_test.txt`。已有同名文件时逐字节比较，拒绝覆盖不同内容。整套输入来源、作用、行数、各自摘要和原字节/LF文本口径在 `data/manifests/exact_fast/exact_fast_population.csv`，逐条筛除标记与分层计数在 `perf_results/sampling/`。独立复核入口 `auditPerfRoster(root)` 从该原始官方名单与两个历史输入登记重建各层完整排序和两个配额，逐份重新检查选中标注及其二值像素/尺寸/结构。选样结束会调用一次，结果为 `independent_check.json`。审核包已有200份选中标注时，完整官方大包可缺省，收据会明确记录是否再次散列了原始大包。

这里的家族按可核对的文件关系、视图和旧指纹图谱定义，计数单位是来源文件家族。Oxford未给出完整的宠物个体身份或采集场次，不能仅凭每个家族一个代表推断同一只宠物绝不会出现在不同家族。官方压缩包本身不设表格行数，总体声明的 rows 对该项不适用。

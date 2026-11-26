# 两项主要结果的独立复算

从解压后的项目根目录执行以下命令。需要新确认的原始标注、十二份会话 JSONL、实际 PM31 和冻结分析生成的声明文件。

```powershell
matlab -singleCompThread -batch "addpath('perf_results/independent_audit'); disp(auditPrimary(pwd))"
```

脚本逐行核对固定工作量的 1,152 次调用以及限时网格的 7,200 次调用。A 的 48 个源使用新旧跨圈的相同动作和文件轨迹，对总返回时间取源等权几何平均比。B 只选择 100 ms 前最后一次实收，比较相同源、会话、重复的快版圈内和跨圈实际文件。双侧均成功且长度相同时，从字节独立解码并以官方索引标注的标签 1 重算 XOR。

`pair_disposition.csv` 按预定配对记录两侧终态、是否可用及纳入理由。可用位标中，第一侧和第二侧分别贡献 1 和 2。固定网格第一侧为 old_cross，限时网格第一侧为 fast_within。逐源重算值和声明对照可分别查看 `source_recalculation.csv` 和 `comparison.csv`。按重复、会话、源逐层平均，并独立实现种子 40121 的 10,000 次源重抽及百分位插值。`receipt.json` 保存最终数值和通过状态。

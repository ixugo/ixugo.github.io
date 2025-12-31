---
title: YOU ONLY LOOK ONCE
description: 
date: 2025-12-09
slug: 
image: 
draft: true
categories:
    - Python
tags:
    - Python
    - AI
    - Pytorch
---

## 标记图形

推荐使用 http://makesense.ai/ 

1. 推荐按字母序排列标签
2. 建议选择与标签相关联的颜色
3. 跳过不包含需要检测的元素或它们不清晰的图像
4. 避免混淆模型，如果目标部分不可见，考虑是否要标记! 要么都标记要么都不标记!
5. 标记的质量，不应该是批量大面积的选择框，而是每个单位的选择框

### 指标分析

`精度 = tp/(tp+fp)`

`召回率 = tp/(tp+fn)` 

![image-20251209161556326](http://img.golang.space/img-1765268156566.png)

置信度，预测结果的可能性

![image-20251209164241088](http://img.golang.space/img-1765269761264.png)
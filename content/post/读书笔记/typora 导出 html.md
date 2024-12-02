---
title: typora 导出带图片的 html 
description: 
date: 2024-12-01
slug: 
image: 
draft: false
categories:
tags:
---



typora 在导出 HTML 文件时，其图片位置是根据写 markdown 时间定义的，比如在 markdown 中是网络图片，则导出 HTML 也是网络图片。

图片在编辑者本地，或图片在网络但 HTML 使用在离线环境，此时图片是无法正确加载的。

通过设置 typora 导出后执行命令，将图片替换成 base64 来解决以上问题。

### 测试环境

typora 1.9.4 

Macbook Pro

### 解决方案

1. 在 typora 导出设置中，给 html 类型导出后执行自定义命令 `~/typora_format_html.sh ${outputPath}`，其中 `${outputPath}` 是导出后的文件路径。

![image-20241203001922342](http://img.golang.space/img-1733156369791.png)

![image-20241203002004434](http://img.golang.space/img-1733156404593.png)

2. 接下来执行  `vim ~/typora_format_html.sh` 写入脚本

```bash
#!/bin/bash

# typora 参数说明
# https://support.typora.io/Export/#variables

# 打印传入的参数
echo "Received HTML file: $1"

# Typora 导出的 HTML 文件路径
html_file=$1


# 检查参数
if [[ -z "$html_file" ]]; then
    echo "No HTML file provided"
    exit 1
fi

# 检查文件是否存在
if [[ ! -f "$html_file" ]]; then
    echo "File not found: $html_file"
    exit 1
fi

# 定义缓存目录
cache_dir=$(mktemp -d)

# 定义转换 img 的函数
convert_img_to_base64() {
    local src_url=$1
    local cache_file="$cache_dir/$(echo -n "$src_url" | md5)"

    # 检查缓存
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        # 下载图片并编码
        if base64_image=$(curl -s "$src_url" | base64); then
            mime_type=$(echo "$src_url" | sed -E 's|.*\.([a-zA-Z0-9]+)$|\1|' | tr '[:upper:]' '[:lower:]')
            base64_data="data:image/$mime_type;base64,$base64_image"
            echo "$base64_data" > "$cache_file"
            echo "$base64_data"
        else
            echo "$src_url" # 下载失败，返回原链接
        fi
    fi
}

# 读取整个文件
content=$(cat "$html_file")

# 提取所有 img 标签的 src 属性
while read -r src; do
    base64_data=$(convert_img_to_base64 "$src")
    content=$(echo "$content" | sed "s|$src|$base64_data|")
done < <(echo "$content" | sed -nE 's/.*<img[^>]*src="([^"]+)".*/\1/p')

# 写回文件
echo "$content" > "$html_file"

# 清理缓存
rm -rf "$cache_dir"

echo "Base64 conversion completed for: $html_file"
```

正常执行导出 HTML 操作，查看文件可以发现图片已经是 base64。

![image-20241203002348395](http://img.golang.space/img-1733156628540.png)
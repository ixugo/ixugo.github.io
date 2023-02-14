---
title: 使用 umi.js 创建项目
description: 
date: 2020-07-15 15:00:00
slug: 
image: 
draft: false
categories:
    - React
tags:
    - React
---



## 1. 创建项目

https://umijs.org/zh-CN/docs/getting-started

```bash
# 创建目录
mkdir myapp && cd myapp
# 创建 umijs@3.x 框架
yarn create @umijs/umi-app
# 安装依赖
yarn
# 启动项目
yarn start

# 创建本地配置
echo "import { defineConfig } from 'umi';" > .umirc.local.ts
```



## 2. 使用 recoil 状态管理库

https://recoiljs.org/docs/introduction/getting-started

```bash
yarn add recoil
```

使用 `RecoilRoot` 包裹

```tsx
import React from 'react';
import { RecoilRoot } from 'recoil';
import styles from './index.less';

export default function IndexPage() {
  return (
    <RecoilRoot>
      <h1 className={styles.title}>Page index</h1>
    </RecoilRoot>
  );
}

```



## 3. 安装 UI 框架

```bash
yarn add semantic-ui-react semantic-ui-css
# 在文件中导入 css
import 'semantic-ui-css/semantic.min.css'
```



## 4. 下拉刷新, 上啦加载

https://github.com/ankeetmaini/react-infinite-scroll-component

https://codesandbox.io/s/yk7637p62z?file=/src/index.js:309-322

```bash
 yarn add react-infinite-scroll-component
 import InfiniteScroll from 'react-infinite-scroll-component';
```

其它( 未使用过, 仅在此插件无法使用时,提供更多选择 )

https://github.com/makotot/react-scrollspy

https://github.com/caseywebdev/react-list

https://github.com/danbovey/react-infinite-scroller



## 5. 上传图片压缩

```ts
    <Form.Input
      id="title"
      type="file"
      multiple
      error={imageError}
      accept="image/*"
      onChange={(e, data) => {
        if (!e.target.files) {
          return;
        }
        if (e.target.files.length > 9) {
          setImageError('图片不能超过 9 张');
          return;
        }
        setImageError(undefined);

        for (let index = 0; index < e.target.files.length; index++) {
          const reader = new FileReader();

          // 图片加载好执行
          reader.onload = function (ev) {
            // 
            var imgFile = ev && ev.target && ev.target.result; //或e.target都是一样的

            function setVal(params: any) {
              if (e && e.target && e.target.files) {
                setImageFiles([
                  ...imageFiles,
                  {
                    name: e.target.files[index].name,
                    img: String(params),
                  },
                ]);
              }
            }
						
            // 压缩图片并将图片塞入数组
            dealImage(String(imgFile), (v: any) => {
              setVal(v);
            });
          };

          // 读取图片
          reader.readAsDataURL(e.target.files[index]);
        }
        console.log(imageFiles);
      }}
      placeholder="请输入琴谱地址"
      // onChange={handleChange}
    />

```

```ts

// 通过canvas压缩base64图片
function dealImage(base64: any, callback: any, w: number = 1000) {
  const newImage = new Image();
  const quality = 0.9; // 压缩系数0-1之间
  newImage.src = base64;
  // newImage.setAttribute('crossOrigin', 'Anonymous'); // url为外域时需要
  let imgWidth;
  let imgHeight;
  newImage.onload = function () {
    // @ts-ignore
    imgWidth = this.width;
    // @ts-ignore
    imgHeight = this.height;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d') as any;
    if (Math.max(imgWidth, imgHeight) > w) {
      if (imgWidth > imgHeight) {
        canvas.width = w;
        canvas.height = (w * imgHeight) / imgWidth;
      } else {
        canvas.height = w;
        canvas.width = (w * imgWidth) / imgHeight;
      }
    } else {
      canvas.width = imgWidth;
      canvas.height = imgHeight;
    }
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    // @ts-ignore
    ctx.drawImage(this, 0, 0, canvas.width, canvas.height);
    const newBase64 = canvas.toDataURL('image/jpeg', quality);
    callback(newBase64);
  };
}
```





## 6. toast

```bash
yarn add react-hot-toast
```



### 7 . 部署

如果是在非根目录下，增加 base 属性用于识别路由，增加 publicPath 属性用于识别静态文件地址。

![image-20211017004213961](http://img.golang.space/shot-1634402534241.png)

![image-20211017004306053](http://img.golang.space/shot-1634402586274.png)

![image-20211017004328086](http://img.golang.space/shot-1634402608308.png)

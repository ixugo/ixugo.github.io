---
title: Git 工作流
description: 
date: 2020-07-22 15:00:00
slug: 
image: 
draft: false
categories:
    - Git
tags:
    - 读书笔记
---

# 工作流

有 4 种常用工作流

+ 集中式
+ 功能分支
+ Git Flow
+ Forking



## 集中式

本地修改后直接提交到远程 master，有冲突解决冲突。

团队不建议使用，代码混乱，容易出问题。

![](http://img.golang.space/shot-1650977135936.png)

![img](http://img.golang.space/shot-1650977394648.png)

## 功能分支

功能分支工作流基于集中式工作流演进而来。适合开发团队相对固定，规模较小的项目。

开发新功能时，基于 master 分支创建一个临时功能分支，在分支上开发，开发完成后合并到 master。

+ 仅在最后一步合并到 master 分支，使提交历史更简洁
+ 不同的功能分配给不同的开发人员，避免冲突

![img](http://img.golang.space/shot-1650977416117.png)

### 具体流程

1. 基于 master 创建功能分支

   ```bash
   git checkout -b feature/xxx
   ```

2. 在分支开发，推送到远程

   ```bash
   git add xxx.go
   git commit -m "add xxx"
   git push origin feature/xxx
   ```

3. 创建 PR

   ![img](https://static001.geekbang.org/resource/image/db/ac/dbcd25542515788c7f4f2f592d0029ac.png)

4. 代码管理员对代码做 Code Review，审查完成合并到 master

   ![img](http://img.golang.space/shot-1650978105353.png)



merge 有三种方法

+ Create a merge commit，`git merge --no-ff`，所有 commit 合并成一个，添加到 master。该命令是指强行关闭 `fast-forward`，但会保存特性分支历史，推荐这种。
+ Squash and merge，`git merge --squash`，将不必要的分支上其 commit 压缩合并，创建一个新的提交添加到 master。
+ Rebase and merge，`git rebase`，将分支所有 commit 依次添加到 master，属于 `fast_forward`方式合并。

![image-20220426211503065](http://img.golang.space/shot-1650978903201.png)

![image-20220426211655586](http://img.golang.space/shot-1650979015721.png)

![image-20220426211746722](http://img.golang.space/shot-1650979066836.png)

## Git Flow

Git Flow 工作流是一个非常成熟的方案，也是非开源项目中最常用到的工作流。适合大型的项目或者迭代速度快的项目。

5 种分支

| 分支名  | 描述                                                         |
| ------- | ------------------------------------------------------------ |
| master  | 发布状态，禁止开发，每次合并 hotfix/release 要打版本标签     |
| develop | 最新代码，禁止开发                                           |
| feature | 研发功能分支，基于 develop，开发完成后合并到 develop 并删除该分支 |
| release | 预发布分支，基于 develop，通过测试后合并到 master 和 develop，并删除该分支 |
| hotfix  | 维护阶段分支，紧急 bug 修复，基于 master 分支创建，完成后合并到 master 和 develop 并删除 |

![](http://img.golang.space/shot-1650980272427.png)



## Forking

开源项目中，最常用到的是 Forking 工作流。

假设开发者 A 拥有一个远程仓库，如果开发者 B 也想参与 A 项目的开发，B 可以 fork 一份 A 的远程仓库到自己的 GitHub 账号下，在自己的仓库中修改，完成后向 A 的仓库提交 PR。

![img](http://img.golang.space/shot-1650980499917.png)

### 具体流程

1. fork 仓库

2. 克隆仓库

   ```bash
   git clone https://github.com/xxx/kitx
   cd kitx
   git remote add upstream https://github.com/ixugo/kitx
   # 禁止推送到 upstream ，实际上一般也没有权限，因为那并不是你的仓库
   git remote set-url --push upstream no_pus
   ```

3. 创建功能分支

   ```bash
   # 要同步 master 最新状态
   git fetch upstream
   git checkout master && git rebase upstream/master
   # 创建分支
   git checkout -b feature/files
   ```

4. 完成开发，提交

   ```bash
   # 在特性分支，同步远程仓库最新状态
   git fetch upstream && git rebase upstream/master
   # 提交代码
   git add file.go
   git commit -m "xxx 功能"
   # 推送到自己的远程仓库
   git push origin feature/files
   ```

5. 在 github 自己的仓库那，创建 Pull request。



## 参考

[Go 语言项目开发实战](https://time.geekbang.org/column/intro/100079601?tab=catalog)

[A successful Git branching model](https://nvie.com/posts/a-successful-git-branching-model/)

[Git、GitHub、GitLab Flow，傻傻分不清？一图看懂各种分支管理模型](https://juejin.cn/post/7047529253428002830)

[Git flow 开发指南](https://juejin.cn/post/7050008713003794469)

[gitflow 是什么，有哪些优缺点？](https://juejin.cn/post/6989145079667490847)

[Github 官方文档 pull requests 流程](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/configuring-a-remote-for-a-fork)
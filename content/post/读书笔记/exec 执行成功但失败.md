---
title: Exec 执行成功但失败!
description: 
date: 2024-05-26
slug: 
image: 
draft: false
categories:
    - Go
tags:
    - 错误分析

---



类似以下代码，执行提示失败了，但是转码结果有输出。

错误是 `ERROR exec: "ffmpeg": executable file not found in $PATH`

```go
func ffmpegPipeExec(ctx context.Context, in io.Reader, out io.Writer, args ...string) error {
	argsData := append(append([]string{"-y", "-hide_banner", "-loglevel", "error", "-i", "pipe:0"}, args...), "pipe:1")
	cmd := exec.CommandContext(ctx, "ffmpeg", argsData...) // nolint
	cmd.Stdin = in
	cmd.Stdout = out
	errOut := bytes.NewBuffer(nil)
	cmd.Stderr = errOut
	if err := cmd.Run(); err != nil {
    slog.Error(err.Error())
	}
	if err := errOut.String(); len(err) > 0 && strings.Contains(err, "Error") {
		return fmt.Errorf(err)
	}
	return nil
}
```

## 问题分析

通过断点检测 Go 基础库，在这里遇到错误。

```go
if filepath.Base(name) == name {
		lp, err := LookPath(name)
		if lp != "" {
			// Update cmd.Path even if err is non-nil.
			// If err is ErrDot (especially on Windows), lp may include a resolved
			// extension (like .exe or .bat) that should be preserved.
			cmd.Path = lp
		}
		if err != nil {
			cmd.Err = err
		}
	}
```

继续深入

```go
path := os.Getenv("PATH")
```

`exec.Command` 会从环境变量中判断可执行文件是否存在。我通过 brew 安装的 ffmpeg，路径在 `/opt/homebrew/bin` 目录下，shell 是有写入 PATH 的。

在终端执行 `echo $PATH  `，可输出详细环境变量，是正常的，那么可能是 vscode 加载环境变量时出现异常。

解决方法在 vscode 的 settings 增加，vscode 可以通过 `${env:Name}` 的语法引用环境变量。

```json
 "go.toolsEnvVars": {
    "PATH": "${env:PATH}:/opt/homebrew/bin"
 }
```

> 为什么都找不到可执行文件，程序却执行成功输出结果了呢?

```go
if err := cmd.Run(); err != nil {
    slog.Error(err.Error())
}
```

在这一行中，没有返回错误，上层执行认为没有错误，写了一个空文件。

这里避免返回的原因是认为 ffmpeg 的错误信息会提供更多详情用于分析，但不应该忽略这个错误，可以将此错误放到最后判断。



## 参考

[Vscode 官方文档](https://code.visualstudio.com/docs/editor/variables-reference)


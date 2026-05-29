---
title: Claude Code 与 SDD 编程
description: 
date: 2026-03-21
slug: 
image: http://img.golang.space/img-1780019430592.png
draft: false
categories:
    - AI
tags:
---



## 一、上下文体系与交互基础

### 1.1 交互基础：`@` 与 `!`

- **`@`**（上下文注入）：`@file.go` 引用文件，`@dir/` 引用目录（自动遵守 `.gitignore`）。AI读取后理解项目结构，输出自动成为下轮对话上下文。
- **`!`**（Shell执行）：`!go test ./...` 直接在对话中执行命令。AI也可主动提议操作，用户审批后执行。逐行使用，无沉浸式子Shell。

### 1.2 CLAUDE.md —— 持久化长期记忆

**五级分层加载**（高优先级覆盖低优先级）：
1. 企业级 `managed-settings.json`（不可覆盖）
2. 命令行参数 `--model`（临时）
3. 项目级个人 `.claude/settings.local.json`（gitignore，不提交）
4. 项目级共享 `.claude/settings.json`（提交Git，团队共享）
5. 用户级 `~/.claude/settings.json`（个人全局）

**CLAUDE.md 查找机制**：
- **向上递归**：从cwd到根目录，沿途所有CLAUDE.md拼接加载。monorepo中极为有用：根目录放全局规范，子服务目录放专属规范，启动时自动合并。
- **向下发现**：子目录的CLAUDE.md按需加载（AI通过 `@` 或 Read 读取该目录文件时才触发），避免启动时撑爆上下文窗口。

**生命周期管理**：
- `/init` —— 扫描项目自动生成CLAUDE.md模板（分析go.mod、Makefile、目录结构等）
- `/memory` —— 在编辑器中系统性编辑CLAUDE.md，保存后即时生效
- 直接用自然语言"请把这条规则记下来"也能追加

**@ 导入语法**：在CLAUDE.md中写 `@~/.claude/contexts/golang-style.md` 可导入外部文件，实现模块化组合。团队共享CLAUDE.md + 个人偏好文件 = 兼顾一致性和个性化。

### 1.3 AGENTS.md —— 跨Agent行业标准

- AGENTS.md放通用规范，CLAUDE.md放CC专属指令，后者用 `@../AGENTS.md` 导入前者

### 1.4 constitution.md —— 项目"宪法"

- 定位：比CLAUDE.md更底层的"根本大法"，存放不可协商的架构原则。CLAUDE.md通过 `@constitution.md` 导入。
- 内容示例：简单性原则（优先标准库）、测试先行铁律（TDD不可协商）、明确性原则（错误必须 `%w` 包装）、单一职责原则。
- **强制执行机制**：`plan.md` 模板中嵌入"Constitution Check"章节，内含门禁清单（简单性/测试先行/明确性），门禁未通过须在"复杂性追踪"中给出理由。
- **引导保障**：在 `CLAUDE.md` 中写明，添加新功能时第一步先用 `@` 读相关包，再对照 `constitution.md` 原则，然后才提方案。
- AI审查代码时做"合宪性审查"（Constitution Check），逐条比对宪法原则。

### 1.5 settings.json 分层配置体系

五层优先级：企业级策略 > 命令行参数 > 项目级个人(local.json, gitignore) > 项目级共享(提交Git) > 用户级全局(~/.claude/)

**引擎切换**：环境变量 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 重定向到国产模型；`settings.json` 的 `env` 中设 `ANTHROPIC_DEFAULT_SONNET_MODEL` 覆盖默认模型。

---

## 二、能力扩展四件套

### 2.1 Slash Commands —— 自定义斜杠指令

**存放位置**：
- 项目级：`./.claude/commands/xxx.md`（提交Git，团队共享，`/help` 中标记为 project）
- 用户级：`~/.claude/commands/xxx.md`（个人跨项目，标记为 gitignored）

**参数系统**：
- `$ARGUMENTS` —— 捕获所有参数（适合不定长自然语言或单一ID）
- `$1` `$2` `$3` —— 位置参数（适合固定顺序的结构化参数）

**Frontmatter 元数据**：`description`（菜单描述）、`argument-hint`（参数提示）、`model`（强制指定模型，好钢用在刀刃上）、`allowed-tools`（最小权限原则，如只给 Read+Grep+`Bash(go vet:*)`）

**嵌入Shell命令**：模板中用 `` !`git diff --staged` `` 实现上下文自动化准备——命令先执行，输出替换到Prompt中再发给AI。这是自定义指令最强大的技巧。

### 2.2 Hooks —— 事件驱动自动化

**核心事件**：
| 事件               | 触发时机     | 典型用途                       |
| ------------------ | ------------ | ------------------------------ |
| `PreToolUse`       | 工具调用前   | 阻止危险操作（如保护main分支） |
| `PostToolUse`      | 工具调用后   | 自动gofmt、goimports           |
| `Notification`     | AI等待用户时 | 弹系统通知                     |
| `SessionStart/End` | 会话生命周期 | 初始化/清理                    |

**配置**：在 `settings.json` 的 `hooks` 下按事件名配置，`matcher` 用 `|` 分隔工具名匹配，`command` 写Shell命令。stdin传JSON事件数据，`jq` 解析。退出码 `0`=放行，`2`=阻止并显示stderr。调试用 `claude --debug`。

### 2.3 MCP Server —— 连接外部系统

MCP解决了直接用 `curl` 调API的四大缺陷：脆弱（Prompt里写API细节易出错）、不安全（Token暴露在对话中）、无状态（多步OAuth难管理）、发现性差（AI不知道API有哪些能力）。

**协议三角色**：
- **Host**（主机）= Claude Code，负责协调、安全策略、用户权限审批
- **Server**（服务器）= 能力提供方，暴露Tools/Resources/Prompts三类能力
- **Client**（客户端）= Host内部为每个Server创建的1对1专线连接器

**三大能力类型**：
- **Tools**：AI可执行的动作（如 `create_issue`），最核心
- **Resources**：AI可引用的数据（如 `@github:issue://123`）
- **Prompts**：封装为Slash Command的工作流模板（如 `/mcp__github__list_prs`）

**安装**：`claude mcp add --transport stdio <name> -- <cmd>`（本地stdio）或 `claude mcp add-json <name> '{...}'`（远程HTTP）。认证凭证通过环境变量注入，AI模型本身不接触Token。

**三种Scope**：`user`（个人全局）、`project`（团队共享，存 `.mcp.json`）、`local`（默认）

**工具命名空间**：`mcp__<server_name>__<tool_name>`，自动避免冲突

**Go实现stdio服务器核心**：循环读stdin JSON-RPC → 路由 `initialize`（声明能力）/`tools/list`（返回工具列表）/`tools/call`（执行逻辑） → stdout写JSON-RPC响应，每行一个JSON对象。

### 2.4 Agent Skills —— AI自主发现的专家能力

**核心区别**：
- Slash Command = 用户主动调用（祈使句）
- Agent Skill = AI自主发现并调用（陈述句，基于description语义匹配）

**文件结构**：`SKILL.md`（入口）+ 辅助文档 + 脚本，放在 `.claude/skills/` 下

**三层渐进式披露**：①启动时只加载 name+description 到系统提示（成本极低）→ ②语义匹配成功后加载SKILL.md主体 → ③脚本/文档被引用时才加载

**最佳实践**：单一职责、description写清"能做什么"+"什么时候用"+触发关键词、版本化管理

### 2.5 Subagent —— 独立上下文的专家分身

单一Agent处理多维度复杂任务时会"精神分裂"（性能优化要激进，安全审查要保守）。Subagent = 独立上下文窗口（不污染主对话）+ 专属System Prompt + 精细工具权限。

**定义文件**（`.claude/agents/xxx.md`）：YAML Frontmatter 定义 name/description/tools/model，Markdown正文为System Prompt（"灵魂"）。`description` 是主Agent发现和委托的依据，必须包含触发关键词。

**三种调用模式**：
- 隐式：AI根据description语义匹配，自主委托
- 显式：用户直接点名 `使用 go-code-security-reviewer 检查...`
- 链式：编排多个Subagent接力（性能优化→安全审查→测试覆盖），实现多智能体工作流

**设计原则**：单一职责、最小权限（只读审查员不应有Write权限）、用 `/agents` 交互式管理、Prompt中给明确指令+示例+约束

---

## 三、自动化闭环

### 3.1 Headless模式 —— AI可编程函数

让Claude Code脱离交互式终端，成为可被脚本和CI调用的"纯函数"：`f(输入) = 输出`。

**核心用法**：
- `claude -p "prompt"` —— 非交互执行，结果输出到stdout后退出
- `cat file | claude -p "..."` —— stdin管道传入大段上下文（日志、代码等）
- `--output-format json` —— 结构化输出，含 `result`（最终结果）、`total_cost_usd`（成本）、`subtype`（success/error）、`duration_ms`（耗时），可用 `jq` 编程处理
- `--output-format stream-json --verbose` —— 实时流式输出（jsonl），每步思考和工具调用立即可见

**CI集成实战**：checkout → 安装CC → 配置国产模型（环境变量） → `git diff | claude -p --output-format json` → `jq '.result'` 提取报告 → `actions/github-script` 评论到PR。全程无人值守。

### 3.2 安全体系

**权限四模式**：`default`（默认审批）→ `acceptEdits`（自动接受文件编辑）→ `plan`（只规划不执行）→ `bypassPermissions`（YOLO，跳过所有审批）

**权限规则**：`settings.json` 中 `permissions.allow/deny` 精确到命令级（如 `Bash(go test:*)`）

**沙箱**：基于OS原语（Linux用bubblewrap/macOS用Seatbelt）隔离文件系统和网络访问

**Checkpointing**：会话级Git快照，`/rewind` 回到任意检查点，AI犯错可时光倒流

### 3.3 实战全流程（SDD）

规范驱动开发的核心思想：代码服务于规范，规范是唯一的"真理之源"。维护软件 = 演进规范，而非修改代码。

```
模糊想法
  → [Prompt+角色设定+多轮澄清] → spec.md（需求规范，与技术解耦）
  → [AI架构师+constitution.md] → plan.md（技术方案）+ api-sketch.md（接口草图）
  → [AI技术组长] → tasks.md（原子任务列表，带依赖和并行标记[P]）
  → [TDD循环] RED→GREEN→REFACTOR → 可运行代码
  → [/review指令+Subagent] → 代码审查报告
  → [/commit指令] → Conventional Commits标准化提交
  → [Dockerfile+Makefile+CI] → 容器化+自动化构建+PR审查流水线
  → [维护阶段] Headless模式做根因分析/Checkpointing做安全重构/文档同步
```

**TDD要点**：坚持TDD防AI"自洽幻觉"（代码能跑但逻辑错）；spec.md为唯一意图来源，代码是spec的"编译产物"；Git Worktree实现不同任务并行开发（`git worktree add` 创建隔离工作区）

**驾驶舱框架**：`.claude/`（settings.json/CLAUDE.md/commands/agents/skills/hooks）+ `specs/`（spec.md/plan.md/tasks.md）+ `constitution.md` + `AGENTS.md` + `.mcp.json`

---

## 四、速查：关键命令清单

| 命令              | 用途               |
| ----------------- | ------------------ |
| `/init`           | 生成CLAUDE.md模板  |
| `/memory`         | 编辑CLAUDE.md      |
| `/config`         | 配置主题/快捷键等  |
| `/status`         | 查看当前模型信息   |
| `/help`           | 查看所有可用指令   |
| `/agents`         | 管理Subagent       |
| `/hooks`          | 管理Hooks          |
| `/mcp`            | 查看MCP Server状态 |
| `/rewind`         | 回到检查点         |
| `claude -p "..."` | Headless模式       |
| `claude mcp add`  | 添加MCP Server     |
| `claude --debug`  | 调试模式           |
| `Shift+Tab`       | 切换Plan Mode      |
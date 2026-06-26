# KVD — KWD Versioned Document

**一个自带版本历史的纯文本文件格式。**

每个 `.kvd` 文件就是一个独立的版本仓库——记录了文件的每一次变更：改了什么、什么时间、谁改的。打开文件就能看到完整历史，无需 `.git` 目录。

## 快速开始

### 方式一：kvd 命令行（推荐）

安装后在任意终端使用 `kvd` 命令：

```bash
# 创建一个文件
kvd new notes.kvd -Author me -Content "第一天笔记"

# 修改并自动记录版本
kvd set notes.kvd -Author me -Message "补充内容" -Content "第二天笔记"

# 查看历史
kvd log notes.kvd -Detailed

# 验证完整性
kvd check notes.kvd

# 查看纯净内容（不显示元数据）
kvd show notes.kvd
```

### 方式二：PowerShell

```powershell
# 导入模块（也可在 $PROFILE 中自动加载）
Import-Module KvdModule

# 创建文件
New-KvdFile -Path notes.kvd -Author "me" -Content "第一天笔记"

# 修改
Set-KvdContent -Path notes.kvd -Author "me" -Message "补充" -Content "第二天笔记"

# 查看历史
Get-KvdHistory -Path notes.kvd -Detailed

# 验证完整性
Test-KvdFile -Path notes.kvd
```

### 方式三：双击查看

关联文件类型后，双击 `.kvd` 文件即可用记事本查看纯净内容（右键管理员运行 `tools\register-kvd.bat` 注册关联）。

## 安装

```bash
# 1. 克隆仓库
git clone https://github.com/KWELLDO/kvd.git

# 2. kvd 命令已自动注册到 PATH（重新打开终端即可使用）
# 3. PowerShell 模块已配置自动加载
```

## 核心特性

- **自包含** — 一个文件就是整个版本仓库，复制发送即可
- **人类可读** — 纯文本格式，记事本/任何文本编辑器均可打开
- **哈希链校验** — SHA256 保证历史完整性，篡改可检测
- **增量压缩** — 借鉴 Git 的 delta 算法，旧版本只存差异，节省空间
- **附带查看器** — 双击文件即可查看纯净内容，历史在 HTML 浏览器中展示

## 技术原理

KVD v2 借鉴了 Git 的增量存储思想：

| 技术 | Git | KVD v2 |
|------|-----|--------|
| 增量存储 | pack 文件存差异 | 旧版本存 unified diff |
| 哈希链 | SHA1 对象寻址 | SHA256 校验每次提交 |
| 内容重建 | 沿 delta chain 回溯 | 从 V1 开始正向重算 |
| 最新版缓存 | 取最新文件 | `type:full` 标记 |

格式示例（`type:delta` 只存变化的部分）：

```
>>> 2 | a1b2c3d4
type:delta
author:codex
date:2026-06-26T10:00:00Z
msg:Added timeline
parent:1
---
@@ 7,0,8 @@
+2027 Q1: 公测发布
+2027 Q2: 正式上线
+## 团队成员
+- Alice
<<< 2
```

## 项目结构

```
├── README.md             本文件
├── spec.md               格式规范
├── demo.ps1              PowerShell 演示脚本
└── tools/
    ├── KvdModule.psm1    PowerShell 核心模块（10 个函数）
    ├── KvdModule.psd1    模块清单
    ├── kvd.cmd           命令行入口（已加入 PATH）
    ├── kvd-viewer.ps1    独立查看器（双击看纯净内容）
    ├── kvd-open.bat      Windows 文件关联启动器
    └── register-kvd.bat  注册 .kvd 文件关联
```

## 命令参考

```
kvd new    <path> -Author <name>   -Content <text>    创建文件
kvd set    <path> -Author <name> -Message <msg> -Content <text>  修改文件
kvd get    <path>                                         查看当前内容
kvd log    <path> [-Detailed]                             查看历史
kvd rev    <path> -Revision <n>                           查看指定版本
kvd diff   <path> [-FromRevision <n>] [-ToRevision <n>]  比较版本
kvd check  <path>                                         验证完整性
kvd show   <path>                                         用记事本看纯净内容
kvd view   <path>                                         在浏览器看历史和内容
kvd export <path> [-Revision <n>]                         导出为 txt
```

## License

MIT

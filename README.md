# KVD — KWD Versioned Document

**一个自带版本历史的纯文本文件格式。**

每个 `.kvd` 文件就是一个独立的版本仓库——记录了文件的每一次变更：改了什么、什么时间、谁改的。打开文件就能看到完整历史，无需 `.git` 目录。

## 核心特性

- **自包含** — 一个文件就是整个版本仓库，复制发送即可
- **人类可读** — 纯文本格式，记事本/任何文本编辑器均可打开
- **哈希链校验** — SHA256 保证历史完整性，篡改可检测
- **增量压缩** — 借鉴 Git 的 delta 算法，旧版本只存差异，节省空间
- **附带查看器** — 双击文件即可查看纯净内容，历史在 HTML 浏览器中展示

## 快速开始

```powershell
# 导入模块
Import-Module D:\KWD\kvd\tools\KvdModule.psm1

# 创建文件
New-KvdFile -Path notes.kvd -Author "me" -Content "第一天笔记"

# 修改并自动记录版本
Set-KvdContent -Path notes.kvd -Author "me" -Message "补充内容" -Content (@"
第一天笔记
第二天补充
"@)

# 查看完整历史
Get-KvdHistory -Path notes.kvd -Detailed

# 验证完整性
Test-KvdFile -Path notes.kvd

# 查看纯净内容（不显示元数据）
Show-KvdFile -Path notes.kvd

# 浏览器中查看（带历史时间线）
Show-KvdHistoryView -Path notes.kvd
```

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
├── spec.md                 格式规范
├── demo.ps1                演示脚本
└── tools/
    ├── KvdModule.psm1      PowerShell 核心模块（10 个函数）
    ├── KvdModule.psd1      模块清单
    ├── kvd-viewer.ps1      独立查看器（双击看纯净内容）
    ├── kvd-open.bat        文件关联启动器
    └── register-kvd.bat    注册 .kvd 文件关联
```

## 文件关联

右键管理员运行 `tools/register-kvd.bat`，之后双击 `.kvd` 文件即可用 Notepad 查看纯净内容。

## License

MIT

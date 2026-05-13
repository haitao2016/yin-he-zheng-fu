---
name: self-improving-agent
description: >
  持续自我改进系统。捕获学习、错误和纠正，记录到 .learnings/ 目录的 markdown 文件中，
  实现跨会话的持续改进。
  Use when:
  (1) 命令或操作意外失败时，记录到 ERRORS.md
  (2) 用户纠正了 AI 的错误理解或做法时，记录到 LEARNINGS.md（category: correction）
  (3) 用户请求了当前不支持的功能时，记录到 FEATURE_REQUESTS.md
  (4) API 或外部工具调用失败时，记录到 ERRORS.md
  (5) 发现知识过时或更好的做法时，记录到 LEARNINGS.md（category: knowledge_gap / best_practice）
  (6) 用户说「记录学习」「记录错误」「自我改进」「log learning」「log error」时
  (7) 用户说「查看学习记录」「学习总结」「改进报告」时
  (8) 需要将重要经验提升到项目记忆（CLAUDE.md）时
  MUST trigger when: 检测到操作失败、用户纠正、或用户明确要求记录时自动触发。
  首次使用时自动初始化 .learnings/ 目录和文件。
---

# Self-Improving Agent

捕获开发过程中的学习、错误和纠正，记录到结构化 markdown 文件中，实现持续改进。

---

## 首次初始化

使用前确保 `.learnings/` 目录和文件存在于项目根目录。缺失时自动创建：

```bash
mkdir -p .learnings
[ -f .learnings/LEARNINGS.md ] || printf "# Learnings\n\nCorrections, insights, and knowledge gaps captured during development.\n\n**Categories**: correction | insight | knowledge_gap | best_practice\n\n---\n" > .learnings/LEARNINGS.md
[ -f .learnings/ERRORS.md ] || printf "# Errors\n\nCommand failures and integration errors.\n\n---\n" > .learnings/ERRORS.md
[ -f .learnings/FEATURE_REQUESTS.md ] || printf "# Feature Requests\n\nCapabilities requested by the user.\n\n---\n" > .learnings/FEATURE_REQUESTS.md
```

不要覆盖已有文件。不要记录密钥、token、私钥、环境变量或完整源码/配置文件。

---

## 快速参考

| 场景 | 操作 |
|------|------|
| 命令/操作失败 | 记录到 `.learnings/ERRORS.md` |
| 用户纠正了你 | 记录到 `.learnings/LEARNINGS.md`，category: `correction` |
| 用户想要缺失功能 | 记录到 `.learnings/FEATURE_REQUESTS.md` |
| API/外部工具失败 | 记录到 `.learnings/ERRORS.md`，含集成详情 |
| 知识已过时 | 记录到 `.learnings/LEARNINGS.md`，category: `knowledge_gap` |
| 发现更好方法 | 记录到 `.learnings/LEARNINGS.md`，category: `best_practice` |
| 反复出现的模式 | 更新 `.learnings/LEARNINGS.md`，加 `Pattern-Key` |
| 与已有条目相似 | 用 `**See Also**` 链接，考虑提升优先级 |
| 广泛适用的学习 | 提升到 `CLAUDE.md` 项目记忆 |

---

## 记录格式

### Learning 条目

追加到 `.learnings/LEARNINGS.md`：

```markdown
## [LRN-YYYYMMDD-XXX] category
**Logged**: YYYY-MM-DDTHH:MM:SS
**Priority**: low | medium | high | critical
**Status**: pending
**Area**: frontend | backend | infra | tests | docs | config | gameplay | engine
### Summary
一行描述学到了什么
### Details
完整上下文：发生了什么、什么是错的、什么是正确的
### Suggested Action
具体的修复或改进措施
### Metadata
- Source: conversation | error | user_feedback
- Related Files: path/to/file.ext
- Tags: tag1, tag2
- See Also: LRN-XXXXXXXX-XXX (如果关联已有条目)
```

### Error 条目

追加到 `.learnings/ERRORS.md`：

```markdown
## [ERR-YYYYMMDD-XXX] error_type
**Logged**: YYYY-MM-DDTHH:MM:SS
**Severity**: low | medium | high | critical
**Status**: resolved | pending | ignored
**Context**: command | api | external_tool | build | runtime
### Command Failed
失败的确切命令或操作
### Error Message
实际错误信息 / 异常
### Analysis
出了什么问题以及为什么重要
### Resolution
问题是如何解决的 / 将如何解决
### Prevention
防止类似问题的措施
### Metadata
- Source: automated | manual
- Related Files: path/to/file.ext
- See Also: LRN-XXXXXXXX-XXX, ERR-XXXXXXXX-XXX
```

### Feature Request 条目

追加到 `.learnings/FEATURE_REQUESTS.md`：

```markdown
## [FEAT-YYYYMMDD-XXX] feature_category
**Logged**: YYYY-MM-DDTHH:MM:SS
**Priority**: low | medium | high | critical
**Status**: proposed | approved | implemented | deferred | rejected
**Requested By**: user | internal
### Description
清晰描述请求的功能/能力
### Use Case
为什么需要这个功能 / 解决什么问题
### Implementation Notes
技术考虑 / 依赖
### Status History
- YYYY-MM-DD: 状态变更说明
```

---

## 提升流程

当条目具有广泛适用性时，提升到项目记忆：

1. **评估适用性**
   - 仅针对单次任务？ → 保留在 `.learnings/`
   - 适用于所有未来开发？ → 提升到 `CLAUDE.md`
   - 是通用最佳实践？ → 考虑提升

2. **提升到 CLAUDE.md**
   - 在 CLAUDE.md 中添加简洁的条目
   - 标记原条目 Status 为 `promoted`
   - 格式：`## 简明标题` + 说明 + 示例

3. **更新引用**
   - 确保跨引用链接更新
   - 在原条目 Metadata 中注明已提升

---

## Simplify-and-Harden 工作流

对反复出现需要简化或加固的模式，使用 `Pattern-Key` 跟踪：

```markdown
## [LRN-YYYYMMDD-XXX] best_practice
**Source**: simplify-and-harden
**Priority**: high
### Pattern-Key: category.subtype
例如：simplify.dead_code | harden.input_validation | automate.build
### Issue Being Addressed
被简化/加固的复杂性/风险描述
### Current State → Target State
当前做法 → 期望简化/加固后的做法
### Verification
如何确认成功
```

**关键规则**：
- 使用一致的 Pattern-Key 格式（`category.subtype`）
- 用 `Recurrence-Count` 跟踪复现次数
- 更新已有条目而非创建重复项
- 通过 `See Also` 链接相似模式

---

## 使用流程

### 自动触发

在开发过程中遇到以下情况时自动记录：

1. **构建失败** → 记录到 ERRORS.md，含命令、错误信息、解决方案
2. **用户纠正** → 记录到 LEARNINGS.md，category: correction
3. **发现更好做法** → 记录到 LEARNINGS.md，category: best_practice
4. **API 不符预期** → 记录到 LEARNINGS.md，category: knowledge_gap

### 手动触发

用户说以下内容时触发：
- "记录这个学习" / "log this learning"
- "记录错误" / "log error"
- "添加功能请求" / "feature request"
- "查看学习记录" / "show learnings"
- "改进报告" / "improvement report"

### 回顾与总结

用户请求查看记录时：
1. 读取 `.learnings/` 下所有文件
2. 按优先级和时间排序
3. 提供简洁摘要
4. 建议可提升的条目

---

## 详细格式指南

完整的日志格式规范、高级用法和示例见 [references/usage-guide.md](references/usage-guide.md)。

# MediaWiki 语法速查参考

## 目录
1. 文本格式化
2. 链接
3. 表格
4. 模板
5. 分类
6. 图片与媒体
7. Magic Words
8. 命名空间
9. ParserFunctions
10. Scribunto/Lua 模块

---

## §1 文本格式化

```wikitext
''斜体''
'''粗体'''
'''''粗斜体'''''
<nowiki>不解析wiki标记</nowiki>

= 一级标题 =
== 二级标题 ==
=== 三级标题 ===（最多六级）

* 无序列表项
** 二级列表
# 有序列表项
## 二级有序
; 定义术语
: 定义描述（也用于缩进）

---- → 水平分割线
<br/> → 强制换行
<pre>预格式化块</pre>
<code>行内代码</code>
```

## §2 链接

### 内部链接
```wikitext
[[页面名称]]                     → 链接到本wiki页面
[[页面名称|显示文本]]             → 自定义显示文本
[[页面名称#章节名]]              → 链接到页面特定章节
```

### 外部链接
```wikitext
https://example.com               → 自动识别的裸URL
[https://example.com]             → 编号外部链接 [1]
[https://example.com 显示文本]    → 带文本的外部链接
```

### 跨wiki链接与重定向
```wikitext
[[wikipedia:Main Page]]           → 链接到维基百科
[[w:zh:首页]]                     → 链接到中文维基百科
#REDIRECT [[目标页面]]            → 页面重定向
```

## §3 表格

```wikitext
{| class="wikitable"
|+ 表格标题
|-
\! 表头1 \!\! 表头2 \!\! 表头3
|-
| 单元格1 || 单元格2 || 单元格3
|-
| colspan="2" | 合并两列 || 单元格
|-
| rowspan="2" | 合并两行
| A
|-
| B
|}
```

常用样式：`class="wikitable sortable"`（可排序）、`class="wikitable mw-collapsible"`（可折叠）

## §4 模板

### 调用模板
```wikitext
{{模板名}}                        → 无参数调用
{{模板名|参数1|参数2}}             → 匿名参数（{{{1}}}, {{{2}}}）
{{模板名|name=value}}             → 命名参数
{{subst:模板名}}                  → 替换引用（展开为实际内容）
```

### 编写模板
```wikitext
{{{1}}}                           → 第一个匿名参数
{{{name}}}                        → 命名参数
{{{1|默认值}}}                    → 带默认值的参数

<noinclude>仅在模板页面显示</noinclude>
<includeonly>仅在被引用时显示</includeonly>
<onlyinclude>只包含这部分内容</onlyinclude>
```

## §5 分类

```wikitext
[[Category:分类名称]]             → 将页面加入分类
[[:Category:分类名称]]            → 链接到分类页（不加入）
[[Category:分类名称|排序键]]       → 自定义排序键
{{DEFAULTSORT:排序键}}            → 页面默认排序键
__HIDDENCAT__                     → 隐藏分类（放在分类页面）
```

## §6 图片与媒体

```wikitext
[[File:Example.png]]                           → 原始尺寸
[[File:Example.png|thumb|200px|说明文字]]       → 缩略图
[[File:Example.png|frameless|center|300px]]    → 居中无框
[[File:Example.png|thumb|left|200px|说明]]      → 左浮动
```

参数：`thumb`/`frame`/`frameless`/`border`（类型）、`left`/`right`/`center`/`none`（对齐）、`NNNpx`（宽度）、`link=URL`、`alt=文本`

图库：
```wikitext
<gallery mode="packed" heights="150px">
File:A.png|说明A
File:B.png|说明B
</gallery>
```

支持格式：png, gif, jpg, jpeg, svg, webp, tiff, ico, pdf

## §7 Magic Words

### 行为开关
`__TOC__`（显示目录）、`__NOTOC__`（隐藏目录）、`__FORCETOC__`（强制目录）、`__NOEDITSECTION__`（隐藏编辑链接）

### 常用变量
| 魔术字 | 输出 |
|--------|------|
| `{{PAGENAME}}` | 当前页面名 |
| `{{FULLPAGENAME}}` | 完整页面名（含命名空间） |
| `{{NAMESPACE}}` | 当前命名空间 |
| `{{CURRENTYEAR}}` | 当前年份 |
| `{{CURRENTTIME}}` | 当前时间（HH:MM） |
| `{{SITENAME}}` | 站点名称 |
| `{{SERVER}}` | 服务器URL |
| `{{NUMBEROFPAGES}}` | 总页面数 |
| `{{NUMBEROFARTICLES}}` | 内容页面数 |

### 格式化函数
`{{lc:TEXT}}`（小写）、`{{uc:TEXT}}`（大写）、`{{lcfirst:TEXT}}`、`{{ucfirst:TEXT}}`、`{{PLURAL:N|singular|plural}}`、`{{#tag:tagname|content}}`

## §8 命名空间

| ID | 名称 | 用途 |
|----|------|------|
| 0 | (Main) | 内容页面 |
| 1 | Talk | 讨论页 |
| 2 | User | 用户页面 |
| 4 | Project | 项目页面 |
| 6 | File | 文件描述 |
| 8 | MediaWiki | 系统消息 |
| 10 | Template | 模板 |
| 12 | Help | 帮助 |
| 14 | Category | 分类 |
| 828 | Module | Lua 模块 |

自定义命名空间（LocalSettings.php）：
```php
define("NS_CUSTOM", 3000);
$wgExtraNamespaces[NS_CUSTOM] = "Custom";
```

## §9 ParserFunctions

### 条件判断
```wikitext
{{#if: 字符串 | 非空时 | 为空时}}
{{#ifeq: A | B | 相等时 | 不等时}}
{{#ifexist: 页面名 | 存在时 | 不存在时}}
{{#switch: 值 | A=结果A | B=结果B | #default=默认}}
```

### 数学与日期
```wikitext
{{#expr: 2 + 3 * 4}}              → 14
{{#time: Y年n月j日 | 2024-03-15}} → 2024年3月15日
```

### 字符串函数
```wikitext
{{#len: 字符串}}                   → 长度
{{#sub: 字符串 | 起始 | 长度}}      → 子串
{{#replace: 字符串 | 查找 | 替换}}  → 替换
{{#explode: a-b-c | - | 1}}       → b
{{#titleparts: Help:A/B/C | 1 | 2}} → B
```

## §10 Scribunto/Lua 模块

需安装 Scribunto 扩展（Lua 5.1.x）。

### 模块结构
```lua
-- Module:Hello
local p = {}
function p.hello(frame)
    local name = frame.args[1] or "World"
    return "Hello, " .. name .. "\!"
end
return p
```

### 调用
```wikitext
{{#invoke:Hello|hello|MediaWiki}}  → Hello, MediaWiki\!
```

### 关键要点
- 模块保存在 `Module:` 命名空间，返回 table
- `frame.args` 获取参数，`frame:getParent().args` 获取模板参数
- 可用库：`mw.text`、`mw.uri`、`mw.html`、`mw.title`、`mw.language`
- `mw.loadData()` 加载只读数据模块（比 require 更高效）
- Lua 5.1.x，不支持 5.2+ 特性（goto、整数除法等）

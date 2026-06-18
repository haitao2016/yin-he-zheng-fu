#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
代码健康度检查与优化工具
功能：
  1. 扫描目录下所有代码文件（支持 .lua / .py / .js / .ts / .sh）
  2. 检测重复代码块（相似片段）
  3. 检测冗余逻辑与可简化结构
  4. 检测过大文件 / 过长函数，建议拆分
  5. 生成 Markdown 格式的健康度报告
"""

import os
import sys
import re
import json
import hashlib
import argparse
from collections import defaultdict, Counter
from datetime import datetime
from pathlib import Path


# ============================================================
# 配置
# ============================================================
SUPPORTED_EXT = {'.lua', '.py', '.js', '.ts', '.sh'}
EXCLUDE_DIR_SUFFIXES = ('logs', 'reports', '.git', 'node_modules',
                        '__pycache__', 'dist', 'build', 'game_material',
                        '.agent', '.cli', '.project', '.tmp')

# 阈值
LARGE_FILE_LINES = 600          # 超过此行数视为"大文件"
LONG_FUNCTION_LINES = 80        # 超过此行数的函数建议拆分
DUPLICATE_MIN_LINES = 8         # 重复代码最少行数（低于此不报告）
DUPLICATE_SIMILARITY = 0.85     # 代码相似度阈值（0-1）
TODO_PATTERN = r'(TODO|FIXME|XXX|HACK|BUG)'

# 注释行识别（Lua + Python + shell）
COMMENT_PATTERNS = [
    re.compile(r'^\s*--'),            # Lua
    re.compile(r'^\s*#'),              # Python / shell
    re.compile(r'^\s*//'),             # JS / TS
    re.compile(r'^\s*/\*.*\*/$'),      # JS 单行块注释
]

# 冗余 / 可简化模式
REDUNDANT_PATTERNS = [
    (r'if\s+(.+?)\s+then\s+return\s+true\s+end\s*$',
     '`if cond then return true end` 可简化为 `return cond`'),
    (r'if\s+(.+?)\s+then\s*return\s+false\s+end\s*$',
     '`if cond then return false end` 可简化为 `return not (cond)`'),
    (r'if\s+(.+?)\s+then\s+(.+?)\s*=\s*(true|1)\s+else\s+\2\s*=\s*(false|0|nil)\s+end',
     '`if cond then x = true else x = false end` 可简化为 `x = cond`'),
    (r'\bmath\.min\(math\.max\((.+?),\s*(.+?)\),\s*(.+?)\)',
     '可提取为独立的 clamp() 函数以减少重复'),
    (r'==\s*nil|~\s*=\s*nil|!=\s*None|==\s*None',
     '建议使用显式判空（如 `if x then ... end` 或 `if x is None`）'),
]


# ============================================================
# 工具函数
# ============================================================
def is_comment_line(line):
    """判断是否为注释行"""
    return any(p.match(line) for p in COMMENT_PATTERNS)


def is_blank_line(line):
    return line.strip() == ''


def normalize_line(line):
    """归一化一行代码：去除空白与字符串字面量（用于重复检测）"""
    line = line.strip()
    line = re.sub(r'"[^"]*"', '"STR"', line)
    line = re.sub(r"'[^']*'", "'STR'", line)
    line = re.sub(r'\d+', 'N', line)
    line = re.sub(r'\s+', ' ', line)
    return line


def scan_files(root_dir):
    """递归扫描代码文件"""
    files = []
    for dirpath, _, filenames in os.walk(root_dir):
        parts = [p.lower() for p in Path(dirpath).parts]
        # 跳过排除目录
        if any(p in EXCLUDE_DIR_SUFFIXES for p in parts):
            continue
        if any(p.startswith('.') for p in parts):
            continue
        for fn in filenames:
            ext = Path(fn).suffix.lower()
            if ext in SUPPORTED_EXT:
                files.append(os.path.join(dirpath, fn))
    return sorted(files)


def read_file_lines(path):
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.readlines()
    except Exception:
        return []


# ============================================================
# 1. 基本统计：文件大小、行数、注释率
# ============================================================
def analyze_file_stats(filepath):
    lines = read_file_lines(filepath)
    total = len(lines)
    code = 0
    comment = 0
    blank = 0
    for ln in lines:
        if is_blank_line(ln):
            blank += 1
        elif is_comment_line(ln):
            comment += 1
        else:
            code += 1
    comment_rate = (comment / total * 100) if total > 0 else 0
    return {
        'path': filepath,
        'total_lines': total,
        'code_lines': code,
        'comment_lines': comment,
        'blank_lines': blank,
        'comment_rate': comment_rate,
    }


# ============================================================
# 2. 函数级分析（过长函数 / 建议拆分）
# ============================================================
def find_functions_lua(lines):
    """识别 Lua 中的函数定义及其起始行号"""
    funcs = []
    func_re = re.compile(r'^\s*(local\s+)?function\s+(\S+)', re.IGNORECASE)
    i = 0
    while i < len(lines):
        m = func_re.match(lines[i])
        if m:
            name = m.group(2)
            start = i + 1  # 1-based
            # 找对应 end（简单：扫描到与 function 数量匹配的 end）
            depth = 1
            j = i + 1
            while j < len(lines) and depth > 0:
                # 统计 function / end 的数量（粗略）
                stripped = lines[j].strip()
                # 避免字符串里的关键字影响
                if re.match(r'^function\b', stripped):
                    depth += 1
                # 独立的 "end" 行（或 以 end 结尾 + 无其他关键字）
                if re.match(r'^end\b', stripped):
                    depth -= 1
                j += 1
            end = j  # 1-based，独占
            body_lines = []
            for k in range(i + 1, j - 1):
                if not is_blank_line(lines[k]) and not is_comment_line(lines[k]):
                    body_lines.append(lines[k])
            funcs.append({
                'name': name,
                'start': start,
                'end': end,
                'length': end - start + 1,
                'code_lines': len(body_lines),
            })
            i = j - 1
        i += 1
    return funcs


def find_functions_py(lines):
    funcs = []
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped.startswith('def ') and stripped.endswith(':'):
            name = stripped[4:].split('(')[0].strip()
            start = i + 1
            indent = len(lines[i]) - len(lines[i].lstrip())
            j = i + 1
            while j < len(lines):
                s = lines[j]
                if s.strip() and (len(s) - len(s.lstrip())) <= indent and not s.strip().startswith('#'):
                    break
                j += 1
            end = j
            code_lines = sum(1 for k in range(i + 1, j)
                             if not is_blank_line(lines[k]) and not is_comment_line(lines[k]))
            funcs.append({
                'name': name,
                'start': start,
                'end': end,
                'length': end - start + 1,
                'code_lines': code_lines,
            })
            i = j - 1
        i += 1
    return funcs


def find_functions(filepath, lines):
    ext = Path(filepath).suffix.lower()
    if ext == '.lua':
        return find_functions_lua(lines)
    elif ext == '.py':
        return find_functions_py(lines)
    return []


# ============================================================
# 3. 重复代码检测（基于归一化行的哈希滑动窗口）
# ============================================================
def find_duplicates(files, window=DUPLICATE_MIN_LINES):
    """
    使用滑动窗口 + 哈希指纹检测跨文件重复代码块。
    返回 [(fileA, lineA, fileB, lineB, length), ...]
    """
    # 存储：hash -> [(file, line_no)]
    fingerprint_map = defaultdict(list)

    for f in files:
        lines = read_file_lines(f)
        # 过滤掉纯注释/空行后做窗口，但保留原始行号以便报告
        normalized = [(i + 1, normalize_line(l)) for i, l in enumerate(lines)
                      if not is_blank_line(l) and not is_comment_line(l)]
        # 跳过太短的文件
        if len(normalized) < window:
            continue

        for idx in range(len(normalized) - window + 1):
            block = '\n'.join(t[1] for t in normalized[idx:idx + window])
            h = hashlib.md5(block.encode('utf-8')).hexdigest()
            fingerprint_map[h].append((f, normalized[idx][0]))

    # 找到出现 >= 2 次的指纹
    duplicates = []
    seen_pairs = set()
    for h, occurrences in fingerprint_map.items():
        if len(occurrences) >= 2:
            # 两两组合（但避免同文件相邻重复报告太多）
            for i in range(len(occurrences)):
                for j in range(i + 1, len(occurrences)):
                    fA, lnA = occurrences[i]
                    fB, lnB = occurrences[j]
                    # 避免同一文件相邻行反复报告
                    pair_key = (min(fA, fB), max(fA, fB), abs(lnA - lnB) < 20)
                    if pair_key in seen_pairs:
                        continue
                    seen_pairs.add(pair_key)
                    duplicates.append({
                        'file_a': fA,
                        'line_a': lnA,
                        'file_b': fB,
                        'line_b': lnB,
                        'lines': window,
                    })
                    # 限制每组最多报告 5 条
                    if len(duplicates) > 200:
                        return duplicates
    return duplicates


# ============================================================
# 4. 冗余逻辑 / 可简化结构检测
# ============================================================
def find_redundant_patterns(filepath, lines):
    """检测可简化的 if/return 模式等"""
    issues = []
    for i, line in enumerate(lines):
        for pat, msg in REDUNDANT_PATTERNS:
            try:
                if re.search(pat, line):
                    issues.append({'line': i + 1, 'code': line.strip(), 'suggestion': msg})
                    break
            except re.error:
                continue
    return issues


# ============================================================
# 5. TODO / FIXME 统计
# ============================================================
def find_todos(filepath, lines):
    """检测注释中的 TODO / FIXME / BUG 等标记"""
    todos = []
    pat = re.compile(TODO_PATTERN, re.IGNORECASE)
    script_name = Path(filepath).name

    for i, line in enumerate(lines):
        # 跳过脚本自身的模式定义行（避免自指）
        if script_name == 'code_health_check.py' and 'TODO_PATTERN' in line:
            continue

        stripped = line.strip()

        # Lua 注释
        is_lua_comment = stripped.startswith('--')
        # Python / shell 注释
        is_py_comment = stripped.startswith('#')
        # JS 注释
        is_js_comment = stripped.startswith('//') or stripped.startswith('/*')

        # 只在注释行中搜索，或者包含常见注释前缀的行
        if is_lua_comment or is_py_comment or is_js_comment:
            m = pat.search(line)
            if m:
                # 提取注释文本（去掉前缀）
                text = stripped
                for prefix in ('--', '#', '//', '/*', '*/'):
                    if text.startswith(prefix):
                        text = text[len(prefix):].strip()
                todos.append({'line': i + 1, 'type': m.group(1).upper(), 'text': text})

    return todos


# ============================================================
# 6. 健康度评分
# ============================================================
def compute_health_score(stats):
    """根据统计结果给出 0-100 健康度评分"""
    score = 100

    # 大文件扣分（每个扣 1 分，最多扣 20 分）
    score -= min(len(stats['large_files']) * 1, 20)

    # 长函数扣分（每个扣 0.5 分，最多扣 15 分）
    score -= min(int(len(stats['long_functions']) * 0.5), 15)

    # 重复代码扣分（每组扣 0.5 分，最多扣 15 分）
    score -= min(int(len(stats['duplicates']) * 0.5), 15)

    # 冗余逻辑扣分（每 5 条扣 1 分，最多扣 10 分）
    score -= min(len(stats['redundant_patterns']) // 5, 10)

    # 注释率过低微调（低于 5% 扣 5 分）
    avg_comment = stats['summary']['avg_comment_rate']
    if avg_comment < 5:
        score -= 5

    return max(20, min(100, score))


# ============================================================
# 主流程
# ============================================================
def run_analysis(root_dir):
    print(f"[1/5] 扫描代码文件...")
    files = scan_files(root_dir)
    print(f"      发现 {len(files)} 个代码文件")

    # 基本统计
    print(f"[2/5] 分析文件基本统计...")
    file_stats = []
    for f in files:
        s = analyze_file_stats(f)
        file_stats.append(s)

    # 函数分析
    print(f"[3/5] 分析函数级结构...")
    all_functions = []
    for f in files:
        lines = read_file_lines(f)
        funcs = find_functions(f, lines)
        for fn in funcs:
            fn['file'] = f
            all_functions.append(fn)

    # 重复代码
    print(f"[4/5] 检测重复代码块...")
    duplicates = find_duplicates(files)

    # 冗余逻辑 / TODO
    print(f"[5/5] 检测冗余逻辑与待办...")
    redundant_hits = []
    todo_hits = []
    for f in files:
        lines = read_file_lines(f)
        r = find_redundant_patterns(f, lines)
        for it in r:
            it['file'] = f
            redundant_hits.append(it)
        t = find_todos(f, lines)
        for it in t:
            it['file'] = f
            todo_hits.append(it)

    # 汇总
    total_lines = sum(s['total_lines'] for s in file_stats)
    total_code = sum(s['code_lines'] for s in file_stats)
    total_comment = sum(s['comment_lines'] for s in file_stats)
    avg_comment = (total_comment / total_lines * 100) if total_lines > 0 else 0

    large_files = [s for s in file_stats if s['total_lines'] > LARGE_FILE_LINES]
    long_functions = sorted([fn for fn in all_functions if fn['code_lines'] > LONG_FUNCTION_LINES],
                            key=lambda x: -x['code_lines'])

    summary = {
        'total_files': len(files),
        'total_lines': total_lines,
        'code_lines': total_code,
        'comment_lines': total_comment,
        'avg_comment_rate': avg_comment,
        'total_functions': len(all_functions),
    }

    stats = {
        'summary': summary,
        'file_stats': file_stats,
        'large_files': large_files,
        'long_functions': long_functions[:50],
        'duplicates': duplicates[:50],
        'redundant_patterns': redundant_hits[:50],
        'todos': todo_hits,
    }
    stats['score'] = compute_health_score(stats)
    return stats


# ============================================================
# 报告生成
# ============================================================
def generate_markdown(stats, root_dir, output_path):
    s = stats['summary']
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    lines = []

    lines.append(f"# 代码健康度检查报告")
    lines.append("")
    lines.append(f"- **生成时间**: {now}")
    lines.append(f"- **扫描目录**: `{root_dir}`")
    lines.append(f"- **整体健康度评分**: **{stats['score']} / 100**")
    lines.append("")

    # —— 摘要
    lines.append("## 📊 总体统计")
    lines.append("")
    lines.append("| 指标 | 数值 |")
    lines.append("|------|------|")
    lines.append(f"| 代码文件数 | {s['total_files']} |")
    lines.append(f"| 总行数 | {s['total_lines']:,} |")
    lines.append(f"| 代码行 | {s['code_lines']:,} |")
    lines.append(f"| 注释行 | {s['comment_lines']:,} |")
    lines.append(f"| 平均注释率 | {s['avg_comment_rate']:.1f}% |")
    lines.append(f"| 函数总数 | {s['total_functions']} |")
    lines.append("")

    # —— 大文件
    lines.append("## 📦 大文件建议（建议拆分）")
    lines.append("")
    if stats['large_files']:
        lines.append(f"> 超过 **{LARGE_FILE_LINES}** 行的文件可能承担了过多职责，建议按功能拆分。")
        lines.append("")
        lines.append("| 文件 | 总行数 | 代码行 | 注释率 |")
        lines.append("|------|--------|--------|--------|")
        for f in sorted(stats['large_files'], key=lambda x: -x['total_lines']):
            rel = os.path.relpath(f['path'], root_dir)
            lines.append(f"| `{rel}` | {f['total_lines']} | {f['code_lines']} | {f['comment_rate']:.1f}% |")
        lines.append("")
    else:
        lines.append("_未发现超过阈值的大文件。_")
        lines.append("")

    # —— 过长函数
    lines.append(f"## 🔧 过长函数（> {LONG_FUNCTION_LINES} 代码行，建议拆分）")
    lines.append("")
    if stats['long_functions']:
        lines.append("| 文件 | 函数名 | 行号范围 | 总行数 | 代码行 |")
        lines.append("|------|--------|----------|--------|--------|")
        for fn in stats['long_functions']:
            rel = os.path.relpath(fn['file'], root_dir)
            lines.append(f"| `{rel}` | `{fn['name']}` | L{fn['start']}-L{fn['end']} | {fn['length']} | {fn['code_lines']} |")
        lines.append("")
    else:
        lines.append("_未发现过长函数。_")
        lines.append("")

    # —— 重复代码
    lines.append("## 🔁 重复代码块")
    lines.append("")
    if stats['duplicates']:
        lines.append(f"> 以下位置存在相似代码（至少 **{DUPLICATE_MIN_LINES}** 行），建议抽取为公共函数/模块。")
        lines.append("")
        lines.append("| 位置 A | 位置 B | 涉及行数 |")
        lines.append("|--------|--------|----------|")
        for d in stats['duplicates']:
            relA = os.path.relpath(d['file_a'], root_dir)
            relB = os.path.relpath(d['file_b'], root_dir)
            lines.append(f"| `{relA}:L{d['line_a']}` | `{relB}:L{d['line_b']}` | {d['lines']} 行 |")
        lines.append("")
    else:
        lines.append("_未检测到明显重复代码块。_")
        lines.append("")

    # —— 可简化结构
    lines.append("## 💡 冗余逻辑 / 可简化结构")
    lines.append("")
    if stats['redundant_patterns']:
        lines.append("| 文件 | 行号 | 原代码 | 建议 |")
        lines.append("|------|------|--------|------|")
        for r in stats['redundant_patterns']:
            rel = os.path.relpath(r['file'], root_dir)
            code = r['code'].replace('|', '\\|')[:80]
            lines.append(f"| `{rel}` | L{r['line']} | `{code}` | {r['suggestion']} |")
        lines.append("")
    else:
        lines.append("_未检测到常见可简化模式。_")
        lines.append("")

    # —— TODO
    lines.append("## 📝 待办 / 遗留问题")
    lines.append("")
    if stats['todos']:
        by_type = Counter(t['type'] for t in stats['todos'])
        lines.append("| 类型 | 数量 |")
        lines.append("|------|------|")
        for k, v in by_type.most_common():
            lines.append(f"| {k} | {v} |")
        lines.append("")
        lines.append("### 明细")
        lines.append("")
        for t in stats['todos'][:100]:
            rel = os.path.relpath(t['file'], root_dir)
            lines.append(f"- [{t['type']}] `{rel}:L{t['line']}` — {t['text']}")
        if len(stats['todos']) > 100:
            lines.append(f"- ... 其余 {len(stats['todos']) - 100} 条省略")
        lines.append("")
    else:
        lines.append("_未检测到 TODO/FIXME 标记。_")
        lines.append("")

    # —— 优化建议
    lines.append("## 🚀 优化建议汇总")
    lines.append("")
    suggestions = []
    if stats['large_files']:
        suggestions.append(f"- **文件拆分**: {len(stats['large_files'])} 个文件超过 {LARGE_FILE_LINES} 行，"
                          f"建议按功能拆分为更小的模块。")
    if stats['long_functions']:
        suggestions.append(f"- **函数拆分**: {len(stats['long_functions'])} 个函数逻辑过长，"
                          f"建议将其中重复/独立片段抽取为子函数。")
    if stats['duplicates']:
        suggestions.append(f"- **去重**: 检测到 {len(stats['duplicates'])} 处重复代码，"
                          f"建议抽取公共 util / helper 函数。")
    if stats['redundant_patterns']:
        suggestions.append(f"- **简化逻辑**: {len(stats['redundant_patterns'])} 处冗余 if/return 模式，"
                          f"可直接简化。")
    if stats['todos']:
        suggestions.append(f"- **清理待办**: 共 {len(stats['todos'])} 个 TODO/FIXME 标记，"
                          f"建议按优先级分批处理。")
    if s['avg_comment_rate'] < 5:
        suggestions.append(f"- **补充注释**: 当前平均注释率仅 {s['avg_comment_rate']:.1f}%，"
                          f"建议为核心系统（battle、galaxy、systems）补充模块级注释。")

    if suggestions:
        for sg in suggestions:
            lines.append(sg)
        lines.append("")
    else:
        lines.append("_当前代码库状态良好，无需特别优化建议。_")
        lines.append("")

    lines.append("---")
    lines.append(f"_报告由 `code_health_check.py` 自动生成_")
    lines.append("")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    # 同时保存 JSON 原始数据，方便后续对比趋势
    json_path = output_path.replace('.md', '.json')
    with open(json_path, 'w', encoding='utf-8') as f:
        # 剔除大字段
        slim = dict(stats)
        slim.pop('file_stats', None)
        json.dump(slim, f, ensure_ascii=False, indent=2, default=str)


def main():
    parser = argparse.ArgumentParser(description='代码健康度检查与优化工具')
    parser.add_argument('--dir', default='/workspace/scripts', help='要扫描的根目录')
    parser.add_argument('--output', default=None, help='报告输出路径（默认 reports/code_health_YYYYMMDD_HHMM.md）')
    args = parser.parse_args()

    root_dir = os.path.abspath(args.dir)
    if not os.path.isdir(root_dir):
        print(f"错误: 目录不存在: {root_dir}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        output_path = os.path.abspath(args.output)
    else:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_dir = os.path.join(root_dir, 'reports')
        output_path = os.path.join(output_dir, f'code_health_{timestamp}.md')

    print(f"▶ 开始代码健康度检查")
    print(f"  根目录: {root_dir}")
    print(f"  输出:   {output_path}")
    print("")

    stats = run_analysis(root_dir)
    generate_markdown(stats, root_dir, output_path)

    print("")
    print(f"✅ 检查完成！健康度评分: {stats['score']}/100")
    print(f"   报告已保存: {output_path}")
    print(f"   原始数据:   {output_path.replace('.md', '.json')}")


if __name__ == '__main__':
    main()

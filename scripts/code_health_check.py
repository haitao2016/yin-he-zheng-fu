#!/usr/bin/env python3
"""
Code Health Checker
===================
Scans .lua / .py / .sh code files inside a directory tree, evaluates
multiple code-health indicators, auto-splits oversized files, detects
duplicate blocks / redundant if/return patterns and legacy TODO markers,
then writes a human-readable Markdown report + a JSON raw-data file.

Usage:
    python3 /workspace/scripts/code_health_check.py --dir /workspace/scripts
"""

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# --------------------------------------------------------------------------- #
# 常量 / 阈值                                                                #
# --------------------------------------------------------------------------- #
BIG_FILE_LINES = 600          # 超过该行数视为大文件
LONG_FUNC_LINES = 80          # 超过该行数视为长函数
DUP_MIN_LINES = 8             # 重复代码块最小行数
REPORT_DIR = "/workspace/reports"
SUPPORTED_EXT = (".lua", ".py", ".sh")

# --------------------------------------------------------------------------- #
# 通用工具函数                                                                #
# --------------------------------------------------------------------------- #
def iter_code_files(root: Path):
    """遍历指定目录下所有 .lua / .py / .sh 文件。"""
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in SUPPORTED_EXT:
            continue
        if path.name == os.path.basename(__file__):
            # 跳过自身
            continue
        yield path


def read_lines(path: Path):
    """读文件行（尽力猜测编码）。"""
    for enc in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            with open(path, "r", encoding=enc, errors="strict") as f:
                return f.readlines()
        except (UnicodeDecodeError, OSError):
            continue
    return []


def normalized(line: str) -> str:
    """规范化一行用于重复代码比较：去空白、去字符串常量内容。"""
    s = line.rstrip("\n").strip()
    if not s:
        return ""
    # 抹掉字符串字面量内容，只保留结构
    s = re.sub(r'"[^"]*"', '""', s)
    s = re.sub(r"'[^']*'", "''", s)
    # 抹掉注释
    s = re.sub(r"(--.*)$", "", s)   # lua
    s = re.sub(r"(#.*)$", "", s)    # sh / py
    # 压缩空白
    s = re.sub(r"\s+", " ", s).strip()
    return s


# --------------------------------------------------------------------------- #
# 1) 长函数 / 大函数检测                                                      #
# --------------------------------------------------------------------------- #
LUA_FUNC_START = re.compile(
    r"^\s*(?:local\s+)?function\s+([A-Za-z_][\w:.]*)\s*\("
)
LUA_FUNC_END_RE = re.compile(r"^\s*end\s*(--.*)?$")

PY_FUNC_START = re.compile(r"^(\s*)(?:async\s+)?def\s+([A-Za-z_][\w]*)\s*\(")
PY_CLASS_START = re.compile(r"^(\s*)class\s+([A-Za-z_][\w]*)\s*[:\(]")

SH_FUNC_START = re.compile(r"^([A-Za-z_][\w]*)\s*\(\s*\)\s*\{?\s*$")
SH_FUNC_ALT = re.compile(r"^\s*function\s+([A-Za-z_][\w]*)\s*\(?")


def detect_long_functions(path: Path, lines, threshold=LONG_FUNC_LINES):
    """返回 [(func_name, start_line, end_line, length), ...]"""
    ext = path.suffix.lower()
    result = []

    if ext == ".lua":
        stack = []  # list of (name, start_idx, depth)
        depth = 0
        for idx, line in enumerate(lines):
            m = LUA_FUNC_START.match(line)
            if m:
                stack.append((m.group(1), idx, depth))
                depth += 1
                continue
            # 简单的 end 平衡
            stripped = line.strip()
            if stripped.startswith("end") and stack:
                # 粗略处理：只对顶层 function 弹出
                # 为了精确我们用关键词计数
                pass

        # 更鲁棒的方式：扫描 function/end 配对
        stack = []
        for idx, line in enumerate(lines):
            s = line.strip()
            if LUA_FUNC_START.match(line):
                stack.append(("func", idx))
            elif s.startswith("end") or s == "end":
                if stack and stack[-1][0] == "func":
                    _, start = stack.pop()
                    length = idx - start + 1
                    if length > threshold:
                        name = lines[start].strip().split("(", 1)[0].strip()
                        name = re.sub(r"^function\s*", "", name)
                        name = re.sub(r"^local\s+function\s*", "", name).strip()
                        result.append((name, start + 1, idx + 1, length))
            # 其它结构如 if/for/while 也以 end 结尾，所以 pop 最新的
            elif re.match(r"^(if|for|while)\b", s):
                stack.append(("block", idx))
            elif s.startswith("end"):
                if stack:
                    stack.pop()

    elif ext == ".py":
        stack = []  # (indent, name, start_idx)
        for idx, line in enumerate(lines):
            stripped = line.rstrip("\n")
            if not stripped.strip() or stripped.lstrip().startswith("#"):
                continue
            m = PY_FUNC_START.match(stripped)
            if m:
                indent = len(m.group(1))
                name = m.group(2)
                stack.append((indent, name, idx))
                continue
            # 结束判断：遇到一个与当前缩进相同或更浅的非空/非注释行
            while stack:
                top_indent, top_name, top_start = stack[-1]
                cur_indent = len(stripped) - len(stripped.lstrip())
                if cur_indent <= top_indent:
                    end_idx = idx - 1
                    length = end_idx - top_start + 1
                    if length > threshold:
                        result.append((top_name, top_start + 1, end_idx + 1, length))
                    stack.pop()
                else:
                    break
        # 处理文件末尾的函数
        while stack:
            top_indent, top_name, top_start = stack.pop()
            length = len(lines) - top_start
            if length > threshold:
                result.append((top_name, top_start + 1, len(lines), length))

    elif ext == ".sh":
        # bash 函数基于 {} 或 function 关键字。这里用粗略缩进+关键字法。
        stack = []  # (name, start_idx, brace_open)
        for idx, line in enumerate(lines):
            s = line.strip()
            m = SH_FUNC_START.match(line) or SH_FUNC_ALT.match(line)
            if m:
                stack.append((m.group(1), idx, line.count("{") - line.count("}")))
                continue
            if stack:
                stack[-1] = (stack[-1][0], stack[-1][1],
                             stack[-1][2] + line.count("{") - line.count("}"))
                # 若 open_brace <= 0 且行尾/独立行出现 } 则结束
                if stack[-1][2] <= 0 and ("}" in line or line.strip() == "}"):
                    name, start, _ = stack.pop()
                    length = idx - start + 1
                    if length > threshold:
                        result.append((name, start + 1, idx + 1, length))

    return result


# --------------------------------------------------------------------------- #
# 2) 重复代码块检测（基于行指纹的滑动窗口）                                     #
# --------------------------------------------------------------------------- #
def detect_duplicate_blocks(files_lines, min_lines=DUP_MIN_LINES):
    """
    基于规范化后的行指纹，使用滑动窗口 + 哈希映射，找出所有长度 >= min_lines
    的重复代码段。返回列表：
      [{"files": [(path, start, end), ...], "fingerprint": "...", "lines": N}]
    """
    # fingerprint -> list of (file, start_idx, end_idx)
    fp_map = {}
    step = 4  # 步进，避免指数级输出

    for path, lines in files_lines.items():
        norm = [normalized(l) for l in lines]
        # 收集连续 >= min_lines 且非空的窗口
        n = len(norm)
        i = 0
        while i < n - min_lines + 1:
            # 跳过包含太多纯空行的窗口
            window = norm[i:i + min_lines]
            if sum(1 for w in window if w) < min_lines - 1:
                i += 1
                continue
            fp = hashlib.md5("|".join(window).encode("utf-8")).hexdigest()
            fp_map.setdefault(fp, []).append((str(path), i + 1, i + min_lines))
            i += step

    # 合并/归并：按文件和行号合并连续窗口
    results = []
    for fp, occurrences in fp_map.items():
        if len(occurrences) < 2:
            continue
        # 合并同一文件中相邻窗口
        occ_by_file = {}
        for p, s, e in occurrences:
            occ_by_file.setdefault(p, []).append((s, e))
        merged = []
        for p, ranges in occ_by_file.items():
            ranges.sort()
            cur_s, cur_e = ranges[0]
            for s, e in ranges[1:]:
                if s <= cur_e + step + 2:
                    cur_e = e
                else:
                    merged.append((p, cur_s, cur_e))
                    cur_s, cur_e = s, e
            merged.append((p, cur_s, cur_e))
        # 只有当至少两个位置出现时才算重复
        if len(merged) >= 2:
            results.append({
                "fingerprint": fp,
                "lines": max(e - s + 1 for _, s, e in merged),
                "files": [{"path": p, "start": s, "end": e} for p, s, e in merged],
            })

    # 按重复行数排序
    results.sort(key=lambda r: (-r["lines"], -len(r["files"])))
    return results[:50]  # 限制输出数量避免报告过长


# --------------------------------------------------------------------------- #
# 3) 冗余 if/return 检测                                                      #
# --------------------------------------------------------------------------- #
def detect_redundant_if_return(path: Path, lines):
    """
    识别以下模式：
        if <cond> then
            return true
        else
            return false
        end
    可简化为：  return <cond>
    及类似变体（Python/bash 语法）
    返回 [{ "start": line, "end": line, "suggestion": ..., "original": ... }]
    """
    ext = path.suffix.lower()
    findings = []

    def strip_line(l):
        return l.rstrip("\n").strip()

    if ext == ".lua":
        i = 0
        while i < len(lines):
            s = strip_line(lines[i])
            if re.match(r"^if\s+.+\s+then\s*$", s):
                cond = re.match(r"^if\s+(.+?)\s+then\s*$", s).group(1)
                # 检查 body
                body1 = strip_line(lines[i + 1]) if i + 1 < len(lines) else ""
                else_line = strip_line(lines[i + 2]) if i + 2 < len(lines) else ""
                body2 = strip_line(lines[i + 3]) if i + 3 < len(lines) else ""
                end_line = strip_line(lines[i + 4]) if i + 4 < len(lines) else ""

                cases = [
                    (r"^return\s+true$", r"^return\s+false$", cond),
                    (r"^return\s+false$", r"^return\s+true$", f"not ({cond})"),
                ]
                for bp1, bp2, sugg_cond in cases:
                    if (re.match(bp1, body1) and else_line == "else"
                            and re.match(bp2, body2) and end_line == "end"):
                        findings.append({
                            "start": i + 1,
                            "end": i + 5,
                            "original": "\n".join([strip_line(lines[j])
                                                   for j in range(i, min(i + 5, len(lines)))]),
                            "suggestion": f"return {sugg_cond}",
                        })
                        break
            i += 1

    elif ext == ".py":
        i = 0
        while i < len(lines):
            s = strip_line(lines[i])
            m = re.match(r"^if\s+(.+?)\s*:\s*$", s)
            if m:
                cond = m.group(1)
                # 获取缩进
                base_indent = len(lines[i]) - len(lines[i].lstrip())
                body_indent = None
                j = i + 1
                while j < len(lines) and (not strip_line(lines[j])
                                           or lines[j].lstrip().startswith("#")):
                    j += 1
                if j < len(lines):
                    body_indent = len(lines[j]) - len(lines[j].lstrip())
                    body1 = strip_line(lines[j])
                else:
                    body1 = ""
                    j = i + 1

                # 找 else
                k = j + 1
                while k < len(lines) and (not strip_line(lines[k])
                                          or lines[k].lstrip().startswith("#")):
                    k += 1
                if k < len(lines):
                    else_indent = len(lines[k]) - len(lines[k].lstrip())
                    else_line = strip_line(lines[k])
                else:
                    else_line = ""
                    else_indent = base_indent

                if (body_indent is not None and else_indent == base_indent
                        and else_line == "else:"):
                    m2 = k + 1
                    while m2 < len(lines) and (not strip_line(lines[m2])
                                               or lines[m2].lstrip().startswith("#")):
                        m2 += 1
                    body2 = strip_line(lines[m2]) if m2 < len(lines) else ""

                    cases = [
                        (r"^return\s+True$", r"^return\s+False$", cond),
                        (r"^return\s+False$", r"^return\s+True$", f"not ({cond})"),
                    ]
                    for bp1, bp2, sugg_cond in cases:
                        if re.match(bp1, body1) and re.match(bp2, body2):
                            end_idx = m2
                            findings.append({
                                "start": i + 1,
                                "end": end_idx + 1,
                                "original": "\n".join([strip_line(lines[x])
                                                       for x in range(i, end_idx + 1)]),
                                "suggestion": f"return {sugg_cond}",
                            })
                            break
            i += 1

    elif ext == ".sh":
        i = 0
        while i < len(lines):
            s = strip_line(lines[i])
            if re.match(r"^if\s+.*;?\s*then\s*$", s) or s == "then":
                # 找 return true / fi else return false
                lines_window = [strip_line(lines[j]) for j in range(i, min(i + 10, len(lines)))]
                joined = " || ".join(lines_window)
                if "return 0" in joined and "return 1" in joined and "else" in joined:
                    findings.append({
                        "start": i + 1,
                        "end": min(i + 10, len(lines)),
                        "original": "\n".join(lines_window),
                        "suggestion": "可将 if/else/return 0/1 简化为直接 return $? 或表达式判断",
                    })
            i += 1

    return findings


# --------------------------------------------------------------------------- #
# 4) TODO/FIXME/BUG 标记统计                                                  #
# --------------------------------------------------------------------------- #
TODO_PATTERNS = {
    "TODO": re.compile(r"\b(TODO|todo|Todo)\b[:\s\(]"),
    "FIXME": re.compile(r"\b(FIXME|fixme|Fixme)\b[:\s\(]"),
    "BUG": re.compile(r"\b(BUG|bug|Bug)\b[:\s\(]"),
    "HACK": re.compile(r"\b(HACK|hack|Hack)\b[:\s\(]"),
    "XXX": re.compile(r"\b(XXX)\b[:\s\(]"),
}


def collect_legacy_markers(path: Path, lines):
    """返回 { "TODO": [ ... ], "FIXME": [ ... ], ... } 每项为 (line, text)。"""
    result = {k: [] for k in TODO_PATTERNS}
    for idx, line in enumerate(lines):
        stripped = line.rstrip("\n")
        for name, pat in TODO_PATTERNS.items():
            if pat.search(stripped):
                result[name].append({
                    "line": idx + 1,
                    "text": stripped.strip(),
                })
                break
    return result


# --------------------------------------------------------------------------- #
# 5) 自动拆分大文件                                                            #
# --------------------------------------------------------------------------- #
def split_big_file(path: Path, lines, max_lines=BIG_FILE_LINES):
    """
    当文件超过 max_lines 时，按函数/模块边界拆分：
      - 保持文件头部（模块注释/局部变量/require/import）
      - 将后续每个顶层 function 独立到 *.part_N.lua
    返回 {"original": path, "parts": [new_paths], "header_lines": N} 或 None。
    """
    if len(lines) <= max_lines:
        return None

    ext = path.suffix.lower()
    header_end = 0
    # 以首个顶层函数/类声明作为分界点
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if ext == ".lua" and (
            stripped.startswith("function ") or stripped.startswith("local function ")
        ):
            header_end = idx
            break
        if ext == ".py" and (stripped.startswith("def ") or stripped.startswith("class ")):
            header_end = idx
            break
        if ext == ".sh" and (SH_FUNC_START.match(line) or SH_FUNC_ALT.match(line)):
            header_end = idx
            break

    if header_end == 0:
        # 没有明显函数边界，保守不拆分
        return None

    header = lines[:header_end]

    # 后续按顶层声明切片
    parts = []
    chunk_start = header_end
    cur_chunk_indent = None  # 仅用于 python
    depth = 0  # 用于 lua end 平衡

    def finalize_chunk(start, end_idx):
        if end_idx - start >= 5:
            parts.append(lines[start:end_idx + 1])

    if ext == ".lua":
        i = header_end
        block_start = header_end
        depth = 0
        in_block = False
        while i < len(lines):
            s = lines[i].strip()
            if (s.startswith("function ") or s.startswith("local function ")) and not in_block:
                if block_start != i and depth == 0:
                    # 把之间行作为一个 chunk（比如常量表）
                    if i - block_start >= 3:
                        parts.append(lines[block_start:i])
                block_start = i
                depth = 1
                in_block = True
                i += 1
                continue
            if in_block:
                if re.match(r"^(function|local\s+function|if|for|while)\b", s):
                    depth += 1
                if s == "end" or s.startswith("end"):
                    depth -= 1
                    if depth == 0:
                        # 函数结束
                        parts.append(lines[block_start:i + 1])
                        in_block = False
                        block_start = i + 1
            i += 1
        if block_start < len(lines):
            tail = lines[block_start:]
            if len(tail) >= 3:
                parts.append(tail)
    elif ext == ".py":
        i = header_end
        cur_top = header_end
        cur_indent = None
        while i < len(lines):
            s = lines[i].rstrip("\n")
            if not s.strip() or s.lstrip().startswith("#"):
                i += 1
                continue
            indent = len(s) - len(s.lstrip())
            if s.lstrip().startswith(("def ", "class ")) and indent == 0:
                if cur_indent is not None:
                    parts.append(lines[cur_top:i])
                cur_top = i
                cur_indent = indent
            elif cur_indent is not None and indent == 0:
                parts.append(lines[cur_top:i])
                cur_top = i
                cur_indent = None
            i += 1
        if cur_indent is not None or cur_top < len(lines):
            parts.append(lines[cur_top:])
    elif ext == ".sh":
        i = header_end
        cur_top = header_end
        brace_depth = 0
        in_func = False
        while i < len(lines):
            line = lines[i]
            s = line.strip()
            if not in_func and (SH_FUNC_START.match(line) or SH_FUNC_ALT.match(line)):
                if i != cur_top:
                    parts.append(lines[cur_top:i])
                cur_top = i
                in_func = True
                brace_depth = line.count("{") - line.count("}")
            elif in_func:
                brace_depth += line.count("{") - line.count("}")
                if brace_depth <= 0:
                    parts.append(lines[cur_top:i + 1])
                    in_func = False
                    cur_top = i + 1
            i += 1
        if cur_top < len(lines):
            tail = lines[cur_top:]
            if len(tail) >= 3:
                parts.append(tail)

    if not parts:
        return None

    # 写文件
    part_paths = []
    stem = path.stem
    suffix = path.suffix
    parent = path.parent
    for idx, chunk in enumerate(parts, 1):
        # 先合并小 chunk 以免产生太多 < 20 行文件
        new_path = parent / f"{stem}_part{idx:02d}{suffix}"
        content = [
            f"-- Auto-split from {path.name} by code_health_check.py\n",
            "-- 基于大文件拆分规则（超过 {} 行）\n\n".format(max_lines),
        ]
        if ext == ".py":
            content = [
                f"# Auto-split from {path.name} by code_health_check.py\n",
                f"# 基于大文件拆分规则（超过 {max_lines} 行）\n\n",
            ]
        elif ext == ".sh":
            content = [
                f"#!/usr/bin/env bash\n",
                f"# Auto-split from {path.name} by code_health_check.py\n",
                f"# 基于大文件拆分规则（超过 {max_lines} 行）\n\n",
            ]
        content.extend(chunk)
        with open(new_path, "w", encoding="utf-8") as f:
            f.writelines(content)
        part_paths.append(str(new_path))

    # 在原文件末尾添加说明
    with open(path, "a", encoding="utf-8") as f:
        f.write("\n\n")
        if ext == ".lua":
            f.write("-- NOTE: 此文件已被 code_health_check.py 自动拆分，"
                    "详见同目录 *_part*.lua 文件。\n")
        elif ext == ".py":
            f.write("# NOTE: 此文件已被 code_health_check.py 自动拆分，"
                    "详见同目录 *_part*.py 文件。\n")
        else:
            f.write("# NOTE: 此文件已被 code_health_check.py 自动拆分，"
                    "详见同目录 *_part*.sh 文件。\n")

    return {
        "original": str(path),
        "header_lines": header_end,
        "part_files": part_paths,
        "parts_count": len(part_paths),
    }


# --------------------------------------------------------------------------- #
# 6) 健康度评分                                                                #
# --------------------------------------------------------------------------- #
def compute_health_score(analysis):
    """基于各项指标计算 0-100 的健康度分数。"""
    score = 100.0
    total_files = analysis["summary"]["total_files"] or 1
    total_lines = analysis["summary"]["total_lines"] or 1

    # 大文件：每个 -8 分
    big_count = len(analysis.get("big_files", []))
    score -= big_count * 8

    # 长函数：每个 -3 分
    long_funcs = sum(len(v) for v in analysis.get("long_functions", {}).values())
    score -= long_funcs * 3

    # 重复代码：每组 -2 分（并根据行数额外扣分）
    dup_blocks = analysis.get("duplicate_blocks", [])
    score -= len(dup_blocks) * 2
    score -= min(10, sum(b["lines"] for b in dup_blocks) // 20)

    # 冗余 if/return：每个 -1 分
    redundant_count = sum(len(v) for v in analysis.get("redundant_if_return", {}).values())
    score -= redundant_count * 1

    # 遗留标记：TODO/FIXME/BUG 每个 -0.2 分
    markers_total = 0
    for data in analysis.get("legacy_markers", {}).values():
        for items in data.values():
            markers_total += len(items)
    score -= markers_total * 0.2

    return max(0.0, round(score, 2))


# --------------------------------------------------------------------------- #
# 7) 报告生成                                                                  #
# --------------------------------------------------------------------------- #
def render_markdown(analysis):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = []

    def h(t, level=1):
        lines.append(("#" * level) + " " + t)
        lines.append("")

    def p(txt=""):
        lines.append(txt)
        lines.append("")

    h("代码健康度检查报告", 1)
    p(f"生成时间：{now}")
    p(f"扫描目录：{analysis['scan_dir']}")
    p(f"健康度评分：**{analysis['health_score']:.2f} / 100**")

    # 小结
    h("一、总体概览", 2)
    s = analysis["summary"]
    lines.append("| 指标 | 值 |")
    lines.append("| --- | --- |")
    lines.append(f"| 扫描文件总数 | {s['total_files']} |")
    lines.append(f"| 代码总行数 | {s['total_lines']} |")
    lines.append(f"| 大文件数（>{BIG_FILE_LINES} 行） | {s['big_file_count']} |")
    lines.append(f"| 长函数数（>{LONG_FUNC_LINES} 行） | {s['long_func_count']} |")
    lines.append(f"| 重复代码块数 | {s['dup_block_count']} |")
    lines.append(f"| 冗余 if/return 结构数 | {s['redundant_count']} |")
    lines.append(f"| TODO 标记 | {s['marker_counts']['TODO']} |")
    lines.append(f"| FIXME 标记 | {s['marker_counts']['FIXME']} |")
    lines.append(f"| BUG 标记 | {s['marker_counts']['BUG']} |")
    lines.append(f"| HACK 标记 | {s['marker_counts']['HACK']} |")
    lines.append(f"| XXX 标记 | {s['marker_counts']['XXX']} |")
    p()

    # 大文件
    h("二、大文件分析（超过 600 行自动拆分）", 2)
    if analysis["big_files"]:
        for bf in analysis["big_files"]:
            p(f"### `{bf['path']}` ({bf['lines']} 行)")
            if bf.get("split"):
                lines.append(f"- 已自动拆分：**{bf['split']['parts_count']}** 个新文件")
                for pp in bf["split"]["part_files"]:
                    lines.append(f"  - `{pp}`")
                lines.append("")
            else:
                lines.append("- 建议：按模块/功能人工拆分。")
                lines.append("")
    else:
        p("✅ 未发现大文件。")

    # 长函数
    h("三、长函数分析（超过 80 行）", 2)
    long_funcs = analysis["long_functions"]
    any_long = any(len(v) > 0 for v in long_funcs.values())
    if any_long:
        for path, funcs in long_funcs.items():
            if not funcs:
                continue
            p(f"### `{path}`")
            lines.append("| 函数名 | 起始行 | 结束行 | 行数 |")
            lines.append("| --- | ---: | ---: | ---: |")
            for name, start, end, length in funcs:
                lines.append(f"| `{name}` | {start} | {end} | {length} |")
            lines.append("")
    else:
        p("✅ 未发现长函数。")

    # 重复代码块
    h("四、重复代码块（至少 8 行相似）", 2)
    if analysis["duplicate_blocks"]:
        lines.append("| # | 行数 | 出现位置 |")
        lines.append("| ---: | ---: | --- |")
        for i, block in enumerate(analysis["duplicate_blocks"], 1):
            loc_str = "<br>".join(f"`{f['path']}:{f['start']}-{f['end']}`"
                                   for f in block["files"])
            lines.append(f"| {i} | {block['lines']} | {loc_str} |")
        lines.append("")
        p("建议：将重复代码抽取为公共函数/模块。")
    else:
        p("✅ 未发现明显重复代码块。")

    # 冗余 if/return
    h("五、冗余 if/return 结构", 2)
    if any(len(v) > 0 for v in analysis["redundant_if_return"].values()):
        for path, items in analysis["redundant_if_return"].items():
            if not items:
                continue
            p(f"### `{path}`")
            for item in items:
                lines.append(f"- **行 {item['start']}-{item['end']}**：")
                lines.append("")
                lines.append("```")
                lines.append(item["original"])
                lines.append("```")
                lines.append(f"  - 可简化为：`{item['suggestion']}`")
                lines.append("")
    else:
        p("✅ 未发现冗余 if/return 结构。")

    # 遗留标记
    h("六、遗留标记统计（TODO/FIXME/BUG/HACK/XXX）", 2)
    any_marker = False
    for path, data in analysis["legacy_markers"].items():
        total = sum(len(v) for v in data.values())
        if total == 0:
            continue
        any_marker = True
        p(f"### `{path}` (共 {total} 处)")
        for kind, items in data.items():
            if not items:
                continue
            lines.append(f"- **{kind}**：{len(items)} 处")
            for it in items[:20]:  # 每个类别最多显示 20 条
                lines.append(f"  - 第 {it['line']} 行：`{it['text']}`")
            if len(items) > 20:
                lines.append(f"  - …（还有 {len(items) - 20} 处，详见 JSON 原始数据）")
        lines.append("")
    if not any_marker:
        p("✅ 未发现遗留标记。")

    # 文件级详表
    h("七、文件级详表", 2)
    lines.append("| 文件 | 行数 | 长函数 | 冗余结构 | TODO/FIXME/BUG |")
    lines.append("| --- | ---: | ---: | ---: | ---: |")
    for path, meta in analysis["file_meta"].items():
        markers = analysis["legacy_markers"].get(path, {})
        total_markers = sum(len(v) for v in markers.values())
        long_count = len(analysis["long_functions"].get(path, []))
        red_count = len(analysis["redundant_if_return"].get(path, []))
        lines.append(
            f"| `{path}` | {meta['lines']} | {long_count} | {red_count} | {total_markers} |"
        )
    lines.append("")

    h("八、评分说明", 2)
    p("评分基于以下扣分项，满分 100：")
    lines.append("- 每个大文件：-8")
    lines.append("- 每个长函数：-3")
    lines.append("- 每个重复代码块：-2（额外按总行数扣分，最多 -10）")
    lines.append("- 每个冗余 if/return：-1")
    lines.append("- 每个 TODO/FIXME/BUG/HACK/XXX 标记：-0.2")
    lines.append("")

    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# 主流程                                                                       #
# --------------------------------------------------------------------------- #
def main():
    parser = argparse.ArgumentParser(description="代码健康度检查工具")
    parser.add_argument("--dir", required=True, help="要扫描的目录")
    parser.add_argument("--no-split", action="store_true", help="禁用自动大文件拆分")
    args = parser.parse_args()

    root = Path(args.dir).resolve()
    if not root.exists():
        print(f"[ERROR] 目录不存在：{root}", file=sys.stderr)
        sys.exit(2)

    Path(REPORT_DIR).mkdir(parents=True, exist_ok=True)

    # 1) 收集文件及内容
    files_lines = {}
    for path in iter_code_files(root):
        lines = read_lines(path)
        if lines:
            files_lines[path] = lines

    if not files_lines:
        print(f"[WARN] 在 {root} 下没有找到 .lua/.py/.sh 文件。", file=sys.stderr)

    analysis = {
        "scan_dir": str(root),
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "summary": {
            "total_files": len(files_lines),
            "total_lines": sum(len(v) for v in files_lines.values()),
            "big_file_count": 0,
            "long_func_count": 0,
            "dup_block_count": 0,
            "redundant_count": 0,
            "marker_counts": {k: 0 for k in TODO_PATTERNS},
        },
        "big_files": [],
        "long_functions": {},
        "duplicate_blocks": [],
        "redundant_if_return": {},
        "legacy_markers": {},
        "file_meta": {},
    }

    # 2) 逐文件分析
    for path, lines in files_lines.items():
        rel_key = str(path.relative_to(root) if path.is_relative_to(root) else path)
        analysis["file_meta"][rel_key] = {"lines": len(lines)}

        # 大文件
        is_big = len(lines) > BIG_FILE_LINES
        split_info = None
        if is_big and not args.no_split:
            split_info = split_big_file(path, lines, BIG_FILE_LINES)
        if is_big:
            analysis["summary"]["big_file_count"] += 1
            analysis["big_files"].append({
                "path": rel_key,
                "lines": len(lines),
                "split": split_info,
            })

        # 长函数
        funcs = detect_long_functions(path, lines)
        if funcs:
            analysis["long_functions"][rel_key] = funcs
            analysis["summary"]["long_func_count"] += len(funcs)

        # 冗余 if/return
        rr = detect_redundant_if_return(path, lines)
        if rr:
            analysis["redundant_if_return"][rel_key] = rr
            analysis["summary"]["redundant_count"] += len(rr)

        # 遗留标记
        markers = collect_legacy_markers(path, lines)
        analysis["legacy_markers"][rel_key] = markers
        for k, items in markers.items():
            analysis["summary"]["marker_counts"][k] += len(items)

    # 3) 跨文件重复代码块检测
    dup_blocks = detect_duplicate_blocks(files_lines)
    analysis["duplicate_blocks"] = dup_blocks
    analysis["summary"]["dup_block_count"] = len(dup_blocks)

    # 4) 评分
    analysis["health_score"] = compute_health_score(analysis)

    # 5) 写文件
    stamp = datetime.now().strftime("%Y%m%d_%H%M")
    md_path = f"{REPORT_DIR}/code_health_{stamp}.md"
    json_path = f"{REPORT_DIR}/code_health_{stamp}.json"

    with open(md_path, "w", encoding="utf-8") as f:
        f.write(render_markdown(analysis))
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(analysis, f, ensure_ascii=False, indent=2)

    print(f"[OK] 代码健康度评分：{analysis['health_score']:.2f} / 100")
    print(f"  - Markdown 报告：{md_path}")
    print(f"  - JSON 原始数据：{json_path}")
    print(f"  - 扫描文件：{analysis['summary']['total_files']} 个，"
          f"共 {analysis['summary']['total_lines']} 行")
    print(f"  - 大文件：{analysis['summary']['big_file_count']} 个  "
          f"长函数：{analysis['summary']['long_func_count']} 个  "
          f"重复块：{analysis['summary']['dup_block_count']} 组  "
          f"冗余结构：{analysis['summary']['redundant_count']} 处")


if __name__ == "__main__":
    main()

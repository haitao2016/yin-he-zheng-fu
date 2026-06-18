#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
代码健康度检查与优化工具
功能：
  1. 扫描目录下所有代码文件（支持 .lua / .py / .js / .ts / .sh）
  2. 检测重复代码块（相似片段）
  3. 检测冗余逻辑与可简化结构
  4. 检测过大文件 / 过长函数，建议拆分
  5. 智能生成大文件代码拆分方案（可自动执行）
  6. 生成 Markdown 格式的健康度报告
"""

import os
import sys
import re
import json
import shutil
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
# 7. 大文件代码拆分器（核心新增功能）
# ============================================================

def identify_code_blocks_lua(lines, funcs):
    """
    智能识别 Lua 文件中的代码区块：
      - header:    模块头部注释 + local Module = {} 声明
      - config:    配置常量区块（local CONFIG_KEY = value）
      - data:      数据表区块（local TABLE = { ... }）
      - function:  函数区块（已由 find_functions_lua 识别）
      - footer:    return ModuleName 等尾部代码
    返回: list of dict, 每个元素:
        { 'type': str, 'start': int, 'end': int, 'name': str, 'lines': int }
    """
    blocks = []

    # Step 1: 识别模块头部（开头到第一个非注释/空行/配置之前的内容）
    header_end = 0
    for i in range(min(20, len(lines))):
        stripped = lines[i].strip()
        if stripped.startswith('local ') and '=' in stripped and 'function' not in stripped:
            break
        if stripped.startswith('local ') and 'function' in stripped:
            break
        header_end = i

    # 更精确的头部识别：找到第一个 function 或第一个配置常量前的代码
    first_func_line = min((f['start'] - 1 for f in funcs), default=len(lines))
    first_config_line = len(lines)
    for i in range(len(lines)):
        s = lines[i].strip()
        if (s.startswith('local ') and '=' in s and 'function' not in s
                and not s.startswith('local function')):
            # 找到第一个配置常量声明
            if '{' in s or not any(c in s for c in ('return', 'require')):
                first_config_line = i
                break

    header_end = min(first_func_line, first_config_line) - 1
    if header_end > 0:
        blocks.append({
            'type': 'header',
            'start': 1,
            'end': header_end + 1,
            'name': '模块头部（注释、模块声明）',
            'lines': header_end + 1,
        })

    # Step 2: 识别配置常量区块（在 header 之后、第一个函数/数据表之前）
    # 寻找形如 local CONST_NAME = value 的连续行
    config_start = None
    i = header_end + 1
    while i < first_func_line and i < len(lines):
        s = lines[i].strip()
        is_config_like = (s.startswith('local ') and '=' in s
                          and 'function' not in s and '{' not in s)
        is_comment = s.startswith('--') or s == ''
        is_separator_comment = s.startswith('--') and ('===' in s or '---' in s)

        if is_config_like or (is_comment and not is_separator_comment and config_start is not None):
            if config_start is None:
                config_start = i + 1
        else:
            if config_start is not None:
                blocks.append({
                    'type': 'config',
                    'start': config_start,
                    'end': i,
                    'name': '配置常量',
                    'lines': i - config_start + 1,
                })
                config_start = None
        i += 1

    if config_start is not None:
        end_line = min(first_func_line, len(lines))
        blocks.append({
            'type': 'config',
            'start': config_start,
            'end': end_line,
            'name': '配置常量',
            'lines': end_line - config_start + 1,
        })

    # Step 3: 识别数据表区块（local TABLE_NAME = { ... } 的大表）
    # 简单策略：找以 local 开头并包含 { 的行，然后匹配到对应的闭合 }
    i = header_end + 1
    while i < len(lines):
        s = lines[i].strip()
        if s.startswith('local ') and '=' in s and '{' in s and 'function' not in s:
            # 可能是一个数据表开始
            table_name_match = re.match(r'local\s+(\w+)\s*=', s)
            if table_name_match:
                tname = table_name_match.group(1)
                # 找匹配的闭合括号（粗略：统计 { 和 }）
                brace_count = 0
                j = i
                while j < len(lines):
                    brace_count += lines[j].count('{')
                    brace_count -= lines[j].count('}')
                    j += 1
                    if brace_count <= 0 and j > i + 1:
                        break
                # 如果这个表至少 5 行则作为独立数据块
                if j - i >= 5:
                    blocks.append({
                        'type': 'data',
                        'start': i + 1,
                        'end': j,
                        'name': f'数据表: {tname}',
                        'lines': j - i,
                    })
                    i = j
                    continue
        i += 1

    # Step 4: 函数区块（直接使用 find_functions_lua 的结果）
    for f in funcs:
        blocks.append({
            'type': 'function',
            'start': f['start'],
            'end': f['end'],
            'name': f['name'],
            'lines': f['length'],
            'code_lines': f['code_lines'],
        })

    # Step 5: 识别 return 语句作为 footer
    for i in range(len(lines) - 1, max(0, len(lines) - 10), -1):
        if lines[i].strip().startswith('return '):
            blocks.append({
                'type': 'footer',
                'start': i + 1,
                'end': len(lines),
                'name': '模块导出 (return)',
                'lines': len(lines) - i,
            })
            break

    # 按 start 排序
    blocks.sort(key=lambda b: b['start'])
    return blocks


def group_functions_by_module(funcs_blocks):
    """
    根据函数命名规则将函数分组到不同模块。
    策略：
      - ModuleName.FuncName() → 归属于 ModuleName 模块
      - FuncName() → 归属于 general 模块
      - 同名前缀的函数归入同一组
    返回: dict { group_name: [block, block, ...] }
    """
    groups = defaultdict(list)
    for b in funcs_blocks:
        name = b['name']
        # 匹配 Module.Func 模式
        if '.' in name and not name.startswith('_'):
            parts = name.split('.')
            if len(parts) >= 2:
                module = parts[0]
                # 特殊处理：清除括号
                module = module.replace('(', '').replace(')', '')
                groups[module].append(b)
                continue
        # 匹配前缀分组: handleEvent, handleSpawn → handle
        prefix_match = re.match(r'([a-z][a-z0-9_]{2,})', name, re.IGNORECASE)
        if prefix_match:
            prefix = prefix_match.group(1).lower()
            # 只对识别度高的前缀分组（避免过短/通用前缀）
            common_prefixes = ('render', 'handle', 'update', 'draw',
                               'spawn', 'init', 'load', 'save', 'create',
                               'get', 'set', 'find', 'check', 'calc')
            if prefix in common_prefixes:
                groups[prefix].append(b)
                continue
        groups['general'].append(b)
    return groups


def generate_split_plan(filepath, lines, blocks, max_lines_per_file=LARGE_FILE_LINES):
    """
    为大文件生成详细的拆分方案。
    返回: dict 包含:
        - original_file: 原文件路径
        - original_lines: 原文件行数
        - sub_files: list of { name, purpose, line_range, lines, content_preview }
        - refactored_original: 重构后原文件的预览内容（require 语句）
        - strategy: 拆分策略描述
    """
    # 分离各种类型的区块
    headers = [b for b in blocks if b['type'] == 'header']
    configs = [b for b in blocks if b['type'] == 'config']
    datas = [b for b in blocks if b['type'] == 'data']
    func_blocks = [b for b in blocks if b['type'] == 'function']
    footers = [b for b in blocks if b['type'] == 'footer']

    # 按模块前缀对函数分组
    func_groups = group_functions_by_module(func_blocks)

    # 决定拆分策略
    sub_files = []
    base_name = Path(filepath).stem  # 文件名，不含扩展名
    ext = Path(filepath).suffix
    dir_path = str(Path(filepath).parent)

    # —— 1. 如果有配置常量且 ≥ 20 行，独立为 config 文件
    if configs and sum(c['lines'] for c in configs) >= 15:
        start = min(c['start'] for c in configs)
        end = max(c['end'] for c in configs)
        content = ''.join(lines[start - 1:end])
        sub_files.append({
            'filename': f'{base_name}_config{ext}',
            'purpose': '配置常量（从原文件拆分独立模块）',
            'line_range': f'L{start}-L{end}',
            'lines': end - start + 1,
            'content_preview': content[:300].strip() + ('\n...' if len(content) > 300 else ''),
            'block_type': 'config',
            'start_line': start,
            'end_line': end,
        })

    # —— 2. 如果有大数据表，每个独立为 data 文件
    for d in datas:
        if d['lines'] >= 30:
            start, end = d['start'], d['end']
            content = ''.join(lines[start - 1:end])
            # 从数据表名提取文件名
            table_id = d['name'].replace('数据表: ', '')
            # 转换 snake_case
            table_snake = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', table_id).lower()
            sub_files.append({
                'filename': f'{base_name}_{table_snake}{ext}',
                'purpose': f'数据表模块（{table_id} 定义）',
                'line_range': f'L{start}-L{end}',
                'lines': end - start + 1,
                'content_preview': content[:300].strip() + ('\n...' if len(content) > 300 else ''),
                'block_type': 'data',
                'start_line': start,
                'end_line': end,
            })

    # —— 3. 按功能前缀组拆分函数模块
    # 先对组进行大小评估：只对 ≥ 5 个函数或 ≥ 150 行代码的组进行独立拆分
    module_groups = {}
    for group_name, blocks_in_group in func_groups.items():
        total_code = sum(b.get('code_lines', b['lines']) for b in blocks_in_group)
        total_funcs = len(blocks_in_group)
        if total_funcs >= 4 or total_code >= 120:
            module_groups[group_name] = blocks_in_group

    # 剩余函数归回 general（如果 general 组过大，继续拆分）
    for group_name, blocks_in_group in sorted(module_groups.items(),
                                               key=lambda x: -sum(b.get('code_lines', 0) for b in x[1])):
        group_start = min(b['start'] for b in blocks_in_group)
        group_end = max(b['end'] for b in blocks_in_group)
        group_code = sum(b.get('code_lines', b['lines']) for b in blocks_in_group)
        func_names = [b['name'] for b in blocks_in_group]

        # 生成子文件内容预览：取前两个函数的头部
        preview_parts = []
        for b in blocks_in_group[:2]:
            s = b['start'] - 1
            e = min(b['start'] + 3, b['end'])
            preview_parts.append(''.join(lines[s:e]).strip())
        preview_content = '\n\n'.join(preview_parts)

        # 转换 group_name → snake_case 文件名
        fn_base = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', group_name).lower()
        fn_base = fn_base.replace('_', '') if fn_base in ('_', '') else fn_base
        # 处理 special 模式: GalaxyEvents.* 等已有模块前缀的情况
        # 如果 group_name 已经等于 base_name，改为功能描述
        if fn_base == base_name.lower():
            # 用函数前缀描述
            fn_base = 'core'

        sub_files.append({
            'filename': f'{base_name}_{fn_base}{ext}',
            'purpose': f'{group_name} 相关函数（{len(func_names)} 个函数，约 {group_code} 行代码）',
            'line_range': f'L{group_start}-L{group_end}',
            'lines': group_end - group_start + 1,
            'content_preview': preview_content[:300] + ('\n...' if len(preview_content) > 300 else ''),
            'block_type': 'module',
            'functions': func_names,
            'start_line': group_start,
            'end_line': group_end,
        })

    # —— 4. 如果 sub_files 为空，但文件太大，做通用拆分建议
    if not sub_files and len(lines) > max_lines_per_file:
        # 退而求其次：按行号给出分段建议
        chunk_size = max_lines_per_file
        n_chunks = len(lines) // chunk_size + (1 if len(lines) % chunk_size else 0)
        for idx in range(1, n_chunks):
            s = idx * chunk_size + 1
            e = min((idx + 1) * chunk_size, len(lines))
            sub_files.append({
                'filename': f'{base_name}_part{idx + 1}{ext}',
                'purpose': f'第 {idx + 1} 部分（通用分段，建议手动分析后改为有意义的命名）',
                'line_range': f'L{s}-L{e}',
                'lines': e - s + 1,
                'content_preview': ''.join(lines[s - 1:min(s + 10, e)]).strip(),
                'block_type': 'chunk',
                'start_line': s,
                'end_line': e,
            })

    # —— 生成重构后的原文件预览
    # 原文件保留：header（注释、require）+ 新的 require 语句 + footer（return）
    refactored_preview_lines = []

    # 头部注释保留
    header_text = ''
    if headers:
        hs = headers[0]
        header_text = ''.join(lines[hs['start'] - 1:hs['end']]).rstrip()
    else:
        header_text = f'-- {Path(filepath).name}（已重构：核心逻辑已拆分至子模块）'

    refactored_preview_lines.append(header_text)
    refactored_preview_lines.append('')

    # 生成 require 语句
    refactored_preview_lines.append('-- 从拆分后的子模块导入')
    for sf in sub_files:
        # 构造 require 路径（相对脚本目录）
        rel = sf['filename'].replace(ext, '')
        # 推断 require 路径：如果原文件位于 game/xxx.lua，则 require "game.{base}_{suffix}"
        parent = Path(filepath).parent.name
        if parent.lower() in ('scripts', 'game', 'battle', 'ui', 'galaxy', 'systems', 'network'):
            req_path = f'{parent}/{rel}'
        else:
            req_path = rel
        req_path = req_path.replace('/', '.')
        refactored_preview_lines.append(f'local {rel.replace("_", "").title()} = require("{req_path}")')

    refactored_preview_lines.append('')
    refactored_preview_lines.append('-- （剩余核心逻辑位于以下子文件：）')
    for sf in sub_files:
        refactored_preview_lines.append(f'--   * {sf["filename"]}  ({sf["lines"]} 行)  -- {sf["purpose"]}')

    # footer
    if footers:
        ft = footers[0]
        footer_text = ''.join(lines[ft['start'] - 1:ft['end']]).strip()
        refactored_preview_lines.append('')
        refactored_preview_lines.append(footer_text)

    # 策略描述
    total_new_lines = sum(sf['lines'] for sf in sub_files)
    strategy = (
        f'检测到原文件 {len(lines)} 行，超过阈值 {max_lines_per_file} 行。\n'
        f'建议拆分为 {len(sub_files) + 1} 个文件（1 个主文件 + {len(sub_files)} 个子模块），'
        f'总计 {total_new_lines + 50} 行左右代码。'
    )

    return {
        'original_file': filepath,
        'original_name': Path(filepath).name,
        'original_lines': len(lines),
        'sub_files': sub_files,
        'refactored_preview': '\n'.join(refactored_preview_lines),
        'strategy': strategy,
    }


def execute_split_plan(plan, dry_run=True):
    """
    执行拆分计划（当 dry_run=False 时实际写文件）。
    为每个 sub_file 在原文件同目录创建新文件，并将原文件备份为 .bak。
    """
    filepath = plan['original_file']
    parent = Path(filepath).parent
    base_name = Path(filepath).stem
    ext = Path(filepath).suffix

    operations = []

    # Step 1: 备份原文件
    backup_path = str(parent / f'{base_name}{ext}.bak')
    operations.append({
        'action': 'backup',
        'source': filepath,
        'target': backup_path,
    })

    # Step 2: 创建每个子模块文件
    # 注意：这是"建议版本"，需要开发者调整 require 路径后使用
    # 每个子文件：header 注释 + require 必要模块 + 对应代码块
    for sf in plan['sub_files']:
        new_path = str(parent / sf['filename'])
        operations.append({
            'action': 'create_subfile',
            'target': new_path,
            'filename': sf['filename'],
            'purpose': sf['purpose'],
            'source_lines': sf['line_range'],
            'lines': sf['lines'],
        })

    # Step 3: 生成重构后的主文件骨架（不直接覆盖原文件，而是写入 .refactored 文件）
    refactored_path = str(parent / f'{base_name}{ext}.refactored')
    operations.append({
        'action': 'create_refactored_skeleton',
        'target': refactored_path,
        'description': '重构后的主文件骨架（包含 require 语句，具体逻辑需要手动迁移）',
    })

    # 如果不是 dry_run，执行实际操作
    if not dry_run:
        # 备份
        shutil.copy2(filepath, backup_path)

        # 创建每个子模块文件（骨架）
        for sf in plan['sub_files']:
            new_path = str(parent / sf['filename'])
            header_lines = [
                f'-- ============================================================================',
                f'-- {sf["filename"]}  -- {sf["purpose"]}',
                f'-- 由代码健康度检查工具自动生成（拆分自 {Path(filepath).name} {sf["line_range"]}）',
                f'-- ============================================================================',
                '',
                f'local M = {{}}',
                '',
                f'-- TODO: 从 {Path(filepath).name} {sf["line_range"]} 迁移以下代码块到此：',
            ]
            if 'functions' in sf:
                for fn in sf['functions']:
                    header_lines.append(f'--   * function {fn}()')
            header_lines.extend([
                '',
                f'-- M.your_function = function() ... end',
                '',
                f'return M',
                '',
            ])

            with open(new_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(header_lines))

        # 创建重构后主文件骨架
        with open(refactored_path, 'w', encoding='utf-8') as f:
            f.write(plan['refactored_preview'])
            f.write('\n')

    return operations


# ============================================================
# 主流程
# ============================================================
def run_analysis(root_dir, do_split_dry=False, do_split_execute=False):
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

    # ============= 新增：大文件拆分方案分析 =============
    split_plans = []
    split_executed = []

    if large_files:
        print(f"\n[拆分器] 检测到 {len(large_files)} 个大文件，正在生成拆分方案...")
        # 构建快速查找：filepath -> functions
        func_map = defaultdict(list)
        for fn in all_functions:
            func_map[fn['file']].append(fn)

        for fs in sorted(large_files, key=lambda x: -x['total_lines']):
            fpath = fs['path']
            lines = read_file_lines(fpath)
            funcs_in_file = func_map.get(fpath, [])
            ext = Path(fpath).suffix.lower()

            if ext == '.lua':
                blocks = identify_code_blocks_lua(lines, funcs_in_file)
                plan = generate_split_plan(fpath, lines, blocks)
                split_plans.append(plan)
                print(f"    - {Path(fpath).name}: {len(lines)} 行 → 建议拆分为 {len(plan['sub_files']) + 1} 个文件")

                # 执行实际拆分（dry-run 或实际写入）
                if do_split_dry or do_split_execute:
                    ops = execute_split_plan(plan, dry_run=(not do_split_execute))
                    split_executed.append({'plan': plan, 'operations': ops})
                    if do_split_execute:
                        print(f"        → 已创建 {len(ops)} 个文件（含 .bak 备份、子模块骨架、.refactored 主文件）")
                    else:
                        print(f"        → [DRY-RUN] 计划创建 {len(ops)} 个文件（未实际写入）")

    # =====================================================

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
        'split_plans': split_plans,          # 新增：拆分方案
        'split_executed': split_executed,    # 新增：实际执行的操作
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
                          f"建议按功能拆分为更小的模块。"
                          f"（见下方「📦 代码拆分方案」章节）")
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

    # —— 新增：详细的代码拆分方案章节
    if stats.get('split_plans'):
        lines.append("---")
        lines.append("")
        lines.append("# 📦 代码拆分方案（自动生成）")
        lines.append("")
        lines.append(f"> 本次为 **{len(stats['split_plans'])}** 个大文件生成了详细的拆分方案。"
                     f"使用 `--split` 参数可自动创建子模块骨架文件。")
        lines.append("")

        for idx, plan in enumerate(stats['split_plans'], 1):
            lines.append(f"## {idx}. {plan['original_name']}")
            lines.append("")
            lines.append(f"- **原文件路径**: `{os.path.relpath(plan['original_file'], root_dir)}`")
            lines.append(f"- **原文件大小**: {plan['original_lines']:,} 行")
            lines.append(f"- **拆分策略**: {plan['strategy'].replace(chr(10), ' ')}")
            lines.append("")

            # —— 子文件列表
            lines.append("### 建议的子模块文件")
            lines.append("")
            lines.append("| # | 文件名 | 用途 | 行数 | 原位置 |")
            lines.append("|---|--------|------|------|--------|")
            for i, sf in enumerate(plan['sub_files'], 1):
                lines.append(
                    f"| {i} | `{sf['filename']}` | {sf['purpose']} | {sf['lines']} | {sf['line_range']} |")
            lines.append("")

            # —— 每个子文件的内容预览
            lines.append("### 子模块内容预览")
            lines.append("")
            for sf in plan['sub_files']:
                lines.append(f"#### `{sf['filename']}` — {sf['purpose']}")
                lines.append("")
                lines.append(f"- **对应原文件行**: `{sf['line_range']}` ({sf['lines']} 行)")
                lines.append(f"- **区块类型**: `{sf['block_type']}`")
                if sf.get('functions'):
                    func_list = ', '.join(f'`{f}`' for f in sf['functions'][:8])
                    extra = f"（共 {len(sf['functions'])} 个，其余省略）" if len(sf['functions']) > 8 else ""
                    lines.append(f"- **包含函数**: {func_list}{extra}")
                lines.append("")
                lines.append("```lua")
                lines.append(sf['content_preview'])
                lines.append("```")
                lines.append("")

            # —— 重构后主文件预览
            lines.append("### 重构后主文件预览（骨架）")
            lines.append("")
            lines.append("```lua")
            lines.append(plan['refactored_preview'])
            lines.append("```")
            lines.append("")

            # —— 执行方案（如果已执行）
            if stats.get('split_executed'):
                for exec_item in stats['split_executed']:
                    if exec_item['plan']['original_file'] == plan['original_file']:
                        lines.append("### 🛠 已执行操作")
                        lines.append("")
                        lines.append("| 操作 | 目标文件 | 说明 |")
                        lines.append("|------|----------|------|")
                        for op in exec_item['operations']:
                            rel = os.path.relpath(op.get('target', op.get('source', '')), root_dir)
                            desc = op.get('purpose', op.get('description', op['action']))
                            lines.append(f"| `{op['action']}` | `{rel}` | {desc} |")
                        lines.append("")
                        break
            lines.append("---")
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
        # 简化拆分方案中的预览内容（可能很长）
        if 'split_plans' in slim:
            for p in slim['split_plans']:
                p.pop('refactored_preview', None)
                if 'sub_files' in p:
                    for sf in p['sub_files']:
                        sf.pop('content_preview', None)
        json.dump(slim, f, ensure_ascii=False, indent=2, default=str)


def main():
    parser = argparse.ArgumentParser(description='代码健康度检查与优化工具')
    parser.add_argument('--dir', default='/workspace/scripts', help='要扫描的根目录')
    parser.add_argument('--output', default=None, help='报告输出路径（默认 reports/code_health_YYYYMMDD_HHMM.md）')
    parser.add_argument('--split', action='store_true', dest='do_split',
                        help='为每个超过阈值的大文件自动创建子模块骨架文件和 .bak 备份')
    parser.add_argument('--split-dry-run', action='store_true', dest='do_split_dry',
                        help='仅输出拆分计划，不实际创建文件')
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
    if args.do_split:
        print(f"  模式:   🔨 实际执行拆分（创建子模块 + 备份原文件）")
    elif args.do_split_dry:
        print(f"  模式:   🧪 拆分 DRY-RUN（仅显示计划，不实际创建文件）")
    print("")

    stats = run_analysis(root_dir,
                         do_split_dry=args.do_split_dry,
                         do_split_execute=args.do_split)
    generate_markdown(stats, root_dir, output_path)

    print("")
    print(f"✅ 检查完成！健康度评分: {stats['score']}/100")
    print(f"   报告已保存: {output_path}")
    print(f"   原始数据:   {output_path.replace('.md', '.json')}")
    if stats.get('split_plans'):
        n_plans = len(stats['split_plans'])
        print(f"   拆分方案:   为 {n_plans} 个大文件生成了拆分方案")
        if args.do_split:
            print(f"   文件操作:   已创建子模块骨架文件 + .bak 备份 + .refactored 骨架")


if __name__ == '__main__':
    main()

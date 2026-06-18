#!/usr/bin/env python3
"""
代码健康度检查工具
扫描代码文件并生成健康度报告
"""

import os
import re
import json
import argparse
from datetime import datetime
from pathlib import Path
from collections import defaultdict
from difflib import SequenceMatcher
from typing import List, Dict, Any, Tuple, Optional


class CodeHealthChecker:
    """代码健康度检查器"""
    
    # 配置常量
    LARGE_FILE_THRESHOLD = 600  # 大文件行数阈值
    LONG_FUNCTION_THRESHOLD = 80  # 长函数行数阈值
    DUPLICATE_MIN_LINES = 8  # 重复代码块最小行数
    DUPLICATE_SIMILARITY = 0.85  # 相似度阈值
    
    # 遗留标记模式
    TODO_PATTERNS = [
        r'TODO[:\s]',
        r'FIXME[:\s]',
        r'BUG[:\s]',
        r'HACK[:\s]',
        r'XXX[:\s]',
        r'NOTE[:\s]',
    ]
    
    def __init__(self, target_dir: str):
        self.target_dir = Path(target_dir)
        self.results = {
            'scan_time': datetime.now().isoformat(),
            'target_directory': str(self.target_dir),
            'files': {},
            'summary': {
                'total_files': 0,
                'total_lines': 0,
                'large_files': [],
                'long_functions': [],
                'duplicate_blocks': [],
                'redundant_logic': [],
                'todo_markers': [],
                'score': 0,
            },
            'recommendations': []
        }
    
    def scan_files(self) -> List[Path]:
        """扫描目录下的所有代码文件"""
        code_files = []
        extensions = {'.lua', '.py', '.sh'}
        
        for ext in extensions:
            code_files.extend(self.target_dir.rglob(f'*{ext}'))
        
        # 排除 .meta 文件
        code_files = [f for f in code_files if not f.name.endswith('.meta')]
        
        return sorted(code_files)
    
    def count_lines(self, file_path: Path) -> int:
        """统计文件行数"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                return sum(1 for _ in f)
        except Exception:
            return 0
    
    def detect_functions(self, content: str, file_ext: str) -> List[Dict]:
        """检测文件中的函数及其行数"""
        functions = []
        lines = content.split('\n')
        
        if file_ext == '.lua':
            # Lua 函数模式
            patterns = [
                r'^\s*function\s+(\w+(?:\.\w+)*)\s*\(',  # function name()
                r'^\s*local\s+function\s+(\w+)\s*\(',  # local function name()
            ]
            
            func_stack = []
            for i, line in enumerate(lines, 1):
                for pattern in patterns:
                    match = re.match(pattern, line)
                    if match:
                        func_name = match.group(1)
                        func_stack.append({'name': func_name, 'start': i, 'end': i})
                        break
                
                # 检测函数结束 (end 关键字)
                if func_stack and re.match(r'^\s*end\s*$', line):
                    func = func_stack.pop()
                    func['end'] = i
                    func['lines'] = func['end'] - func['start'] + 1
                    functions.append(func)
                    
        elif file_ext == '.py':
            # Python 函数模式
            current_func = None
            current_indent = 0
            
            for i, line in enumerate(lines, 1):
                # 检测函数定义
                match = re.match(r'^(\s*)def\s+(\w+)\s*\(', line)
                if match:
                    indent = len(match.group(1))
                    func_name = match.group(2)
                    
                    # 如果有正在追踪的函数，先结束它
                    if current_func and indent <= current_indent:
                        current_func['end'] = i - 1
                        current_func['lines'] = current_func['end'] - current_func['start'] + 1
                        functions.append(current_func)
                    
                    current_func = {'name': func_name, 'start': i, 'end': i}
                    current_indent = indent
                    
                elif current_func and line.strip() and not line.startswith(' ' * (current_indent + 1)):
                    # 函数结束
                    if not line.startswith(' ' * current_indent) or re.match(r'^\S', line):
                        current_func['end'] = i - 1
                        current_func['lines'] = current_func['end'] - current_func['start'] + 1
                        functions.append(current_func)
                        current_func = None
            
            # 处理文件末尾的函数
            if current_func:
                current_func['end'] = len(lines)
                current_func['lines'] = current_func['end'] - current_func['start'] + 1
                functions.append(current_func)
                
        elif file_ext == '.sh':
            # Shell 函数模式
            for i, line in enumerate(lines, 1):
                match = re.match(r'^(\w+)\s*\(\s*\)\s*\{?', line)
                if match:
                    func_name = match.group(1)
                    functions.append({'name': func_name, 'start': i, 'end': i, 'lines': 1})
        
        return functions
    
    def detect_duplicates(self, file_contents: Dict[str, List[str]]) -> List[Dict]:
        """检测重复代码块 (优化版)"""
        all_blocks = self._extract_code_blocks(file_contents)
        duplicates = self._find_similar_blocks(all_blocks)
        return self._deduplicate(duplicates)[:20]

    def _extract_code_blocks(self, file_contents: Dict[str, List[str]]) -> List[Dict]:
        """提取所有候选代码块"""
        all_blocks = []
        step = max(1, self.DUPLICATE_MIN_LINES // 2)
        max_blocks_per_file = 50

        for file_path, lines in file_contents.items():
            block_count = 0
            for i in range(0, len(lines) - self.DUPLICATE_MIN_LINES + 1, step):
                if block_count >= max_blocks_per_file:
                    break
                block_text = self._build_block_text(lines, i)
                if block_text and len(block_text) > 50:
                    all_blocks.append(self._make_block(file_path, i, block_text))
                    block_count += 1
        return all_blocks

    def _build_block_text(self, lines: List[str], start: int) -> str:
        """构建代码块文本"""
        block = lines[start:start + self.DUPLICATE_MIN_LINES]
        return '\n'.join(line.strip() for line in block if line.strip())

    def _make_block(self, file_path: str, start: int, text: str) -> Dict:
        """构造代码块对象"""
        return {
            'file': file_path,
            'start_line': start + 1,
            'end_line': start + self.DUPLICATE_MIN_LINES,
            'content': text,
            'content_hash': hash(text[:100])
        }

    def _find_similar_blocks(self, all_blocks: List[Dict]) -> List[Dict]:
        """查找相似代码块"""
        duplicates = []
        max_comparisons = 10000
        comparison_count = 0
        checked = set()

        for i, block1 in enumerate(all_blocks):
            if comparison_count >= max_comparisons:
                break
            for j, block2 in enumerate(all_blocks[i+1:], i+1):
                if comparison_count >= max_comparisons:
                    break
                comparison_count += 1

                if not self._should_compare(block1, block2, checked, i, j):
                    continue

                similarity = self._calc_similarity(block1, block2)
                if similarity >= self.DUPLICATE_SIMILARITY:
                    duplicates.append(self._make_duplicate(block1, block2, similarity))
        return duplicates

    def _should_compare(self, b1: Dict, b2: Dict, checked: set, i: int, j: int) -> bool:
        """判断两个块是否需要比较"""
        pair_key = (min(i, j), max(i, j))
        if pair_key in checked:
            return False
        checked.add(pair_key)
        if b1['file'] == b2['file'] and abs(b1['start_line'] - b2['start_line']) < self.DUPLICATE_MIN_LINES * 2:
            return False
        return True

    def _calc_similarity(self, b1: Dict, b2: Dict) -> float:
        """计算相似度 (哈希快速过滤)"""
        if b1['content_hash'] != b2['content_hash']:
            return SequenceMatcher(None, b1['content'], b2['content']).ratio()
        return 1.0

    def _make_duplicate(self, b1: Dict, b2: Dict, similarity: float) -> Dict:
        """构造重复代码块对象"""
        return {
            'block1': {'file': b1['file'], 'start': b1['start_line'], 'end': b1['end_line']},
            'block2': {'file': b2['file'], 'start': b2['start_line'], 'end': b2['end_line']},
            'similarity': round(similarity * 100, 1)
        }

    def _deduplicate(self, duplicates: List[Dict]) -> List[Dict]:
        """去重"""
        seen = set()
        unique = []
        for dup in duplicates:
            key = tuple(sorted([
                (dup['block1']['file'], dup['block1']['start']),
                (dup['block2']['file'], dup['block2']['start'])
            ]))
            if key not in seen:
                seen.add(key)
                unique.append(dup)
        return unique
    
    def detect_redundant_logic(self, content: str, file_ext: str) -> List[Dict]:
        """检测冗余的 if/return 逻辑"""
        issues = []
        lines = content.split('\n')
        
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            
            # 检测冗余的 if return true/false 模式
            # 例如: if condition then return true else return false end
            # 可简化为: return condition
            
            if file_ext == '.lua':
                # 检测 if x then return true else return false end
                if re.match(r'^if\s+.+\s+then\s+return\s+true\s+else\s+return\s+false\s+end', stripped):
                    issues.append({
                        'line': i,
                        'type': 'redundant_if_return',
                        'original': stripped,
                        'suggestion': '可简化为: return condition'
                    })
                
                # 检测 if not x then return false else return true end
                if re.match(r'^if\s+not\s+.+\s+then\s+return\s+false\s+else\s+return\s+true\s+end', stripped):
                    issues.append({
                        'line': i,
                        'type': 'redundant_if_return',
                        'original': stripped,
                        'suggestion': '可简化为: return condition'
                    })
                
                # 检测空 if 块
                if re.match(r'^if\s+.+\s+then\s*$', stripped):
                    # 检查下一行是否是 end
                    if i < len(lines) and re.match(r'^\s*end\s*$', lines[i]):
                        issues.append({
                            'line': i,
                            'type': 'empty_if_block',
                            'original': stripped,
                            'suggestion': '空的 if 块，考虑删除'
                        })
                        
            elif file_ext == '.py':
                # Python 模式
                if re.match(r'^if\s+.+:\s*return\s+True\s*$', stripped):
                    next_line = lines[i] if i < len(lines) else ''
                    if 'return False' in next_line:
                        issues.append({
                            'line': i,
                            'type': 'redundant_if_return',
                            'original': stripped,
                            'suggestion': '可简化为: return condition'
                        })
                
                # 检测冗余的 == True/False
                if re.search(r'==\s*(True|False)\s*:', stripped):
                    issues.append({
                        'line': i,
                        'type': 'redundant_comparison',
                        'original': stripped,
                        'suggestion': '可简化布尔比较: 移除 == True/False'
                    })
                    
            elif file_ext == '.sh':
                # Shell 模式
                if re.match(r'^if\s+\[\s*-z\s+"?\$[^"]*"?\s*\];\s*then\s*$', stripped):
                    if i < len(lines) and 'return' in lines[i]:
                        issues.append({
                            'line': i,
                            'type': 'redundant_check',
                            'original': stripped,
                            'suggestion': '考虑使用更简洁的条件判断'
                        })
        
        return issues
    
    def detect_todo_markers(self, content: str) -> List[Dict]:
        """检测 TODO/FIXME/BUG 等遗留标记"""
        markers = []
        lines = content.split('\n')
        
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            # 忽略 docstring/注释/字符串中的误检
            if stripped.startswith('#') or stripped.startswith('"""') or stripped.startswith("'''"):
                continue
            # 忽略仅在字符串中出现的标记
            for pattern in self.TODO_PATTERNS:
                match = re.search(pattern, line, re.IGNORECASE)
                if match:
                    marker_type = match.group(0).strip(':').strip().upper()
                    markers.append({
                        'line': i,
                        'type': marker_type,
                        'content': stripped[:100]
                    })
                    break
        
        return markers
    
    def analyze_file(self, file_path: Path) -> Dict:
        """分析单个文件"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except Exception as e:
            return {'error': str(e)}
        
        lines = content.split('\n')
        line_count = len(lines)
        file_ext = file_path.suffix
        
        result = {
            'path': str(file_path.relative_to(self.target_dir)),
            'extension': file_ext,
            'lines': line_count,
            'is_large': line_count > self.LARGE_FILE_THRESHOLD,
            'functions': [],
            'long_functions': [],
            'todo_markers': [],
            'redundant_logic': []
        }
        
        # 检测函数
        functions = self.detect_functions(content, file_ext)
        result['functions'] = functions
        result['long_functions'] = [f for f in functions if f.get('lines', 0) > self.LONG_FUNCTION_THRESHOLD]
        
        # 检测遗留标记
        result['todo_markers'] = self.detect_todo_markers(content)
        
        # 检测冗余逻辑
        result['redundant_logic'] = self.detect_redundant_logic(content, file_ext)
        
        return result
    
    def calculate_score(self) -> int:
        """计算健康度评分 (0-100)"""
        score = 100
        
        # 大文件扣分 (每个扣 5 分，最多扣 20 分)
        large_file_penalty = min(len(self.results['summary']['large_files']) * 5, 20)
        score -= large_file_penalty
        
        # 长函数扣分 (每个扣 3 分，最多扣 15 分)
        long_func_penalty = min(len(self.results['summary']['long_functions']) * 3, 15)
        score -= long_func_penalty
        
        # 重复代码扣分 (每个扣 4 分，最多扣 20 分)
        duplicate_penalty = min(len(self.results['summary']['duplicate_blocks']) * 4, 20)
        score -= duplicate_penalty
        
        # 冗余逻辑扣分 (每个扣 2 分，最多扣 10 分)
        redundant_penalty = min(len(self.results['summary']['redundant_logic']) * 2, 10)
        score -= redundant_penalty
        
        # 遗留标记扣分 (每个扣 1 分，最多扣 10 分)
        todo_penalty = min(len(self.results['summary']['todo_markers']), 10)
        score -= todo_penalty
        
        # 文件数量奖励 (有文件则不扣分)
        if self.results['summary']['total_files'] == 0:
            score = 0
        
        return max(0, min(100, score))
    
    def generate_recommendations(self):
        """生成优化建议"""
        recommendations = []
        
        # 大文件建议
        if self.results['summary']['large_files']:
            recommendations.append({
                'category': '大文件拆分',
                'priority': 'high',
                'description': f"发现 {len(self.results['summary']['large_files'])} 个超过 {self.LARGE_FILE_THRESHOLD} 行的大文件",
                'action': '建议将大文件按功能模块拆分为多个小文件，每个文件专注于单一职责'
            })
        
        # 长函数建议
        if self.results['summary']['long_functions']:
            recommendations.append({
                'category': '长函数重构',
                'priority': 'high',
                'description': f"发现 {len(self.results['summary']['long_functions'])} 个超过 {self.LONG_FUNCTION_THRESHOLD} 行的长函数",
                'action': '建议将长函数拆分为多个小函数，每个函数只做一件事'
            })
        
        # 重复代码建议
        if self.results['summary']['duplicate_blocks']:
            recommendations.append({
                'category': '重复代码消除',
                'priority': 'medium',
                'description': f"发现 {len(self.results['summary']['duplicate_blocks'])} 处相似度超过 {self.DUPLICATE_SIMILARITY*100:.0f}% 的重复代码块",
                'action': '建议提取公共函数或模块，避免代码重复'
            })
        
        # 冗余逻辑建议
        if self.results['summary']['redundant_logic']:
            recommendations.append({
                'category': '冗余逻辑简化',
                'priority': 'low',
                'description': f"发现 {len(self.results['summary']['redundant_logic'])} 处冗余的 if/return 逻辑",
                'action': '建议简化条件判断，使用更简洁的表达式'
            })
        
        # 遗留标记建议
        if self.results['summary']['todo_markers']:
            todo_count = sum(1 for m in self.results['summary']['todo_markers'] if m['type'] == 'TODO')
            fixme_count = sum(1 for m in self.results['summary']['todo_markers'] if m['type'] == 'FIXME')
            bug_count = sum(1 for m in self.results['summary']['todo_markers'] if m['type'] == 'BUG')
            
            recommendations.append({
                'category': '遗留标记清理',
                'priority': 'medium',
                'description': f"发现 TODO: {todo_count}, FIXME: {fixme_count}, BUG: {bug_count} 个遗留标记",
                'action': '建议及时处理这些遗留标记，避免技术债务积累'
            })
        
        self.results['recommendations'] = recommendations
    
    def run(self) -> Dict:
        """执行代码健康度检查"""
        print(f"开始扫描目录: {self.target_dir}")
        
        # 扫描文件
        code_files = self.scan_files()
        print(f"发现 {len(code_files)} 个代码文件")
        
        # 存储所有文件内容用于重复检测
        file_contents = {}
        
        # 分析每个文件
        for file_path in code_files:
            rel_path = str(file_path.relative_to(self.target_dir))
            print(f"分析: {rel_path}")
            
            result = self.analyze_file(file_path)
            self.results['files'][rel_path] = result
            
            # 读取内容用于重复检测
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    file_contents[rel_path] = f.read().split('\n')
            except Exception:
                pass
            
            # 更新统计
            self.results['summary']['total_files'] += 1
            self.results['summary']['total_lines'] += result.get('lines', 0)
            
            if result.get('is_large'):
                self.results['summary']['large_files'].append({
                    'file': rel_path,
                    'lines': result['lines']
                })
            
            self.results['summary']['long_functions'].extend([
                {'file': rel_path, **f} 
                for f in result.get('long_functions', [])
            ])
            
            self.results['summary']['todo_markers'].extend([
                {'file': rel_path, **m} 
                for m in result.get('todo_markers', [])
            ])
            
            self.results['summary']['redundant_logic'].extend([
                {'file': rel_path, **r} 
                for r in result.get('redundant_logic', [])
            ])
        
        # 检测重复代码
        print("检测重复代码块...")
        self.results['summary']['duplicate_blocks'] = self.detect_duplicates(file_contents)
        
        # 计算评分
        self.results['summary']['score'] = self.calculate_score()
        
        # 生成建议
        self.generate_recommendations()
        
        return self.results


def generate_markdown_report(results: Dict) -> str:
    """生成 Markdown 报告"""
    sections = [
        _render_header(results),
        _render_score(results),
        _render_summary_stats(results),
        _render_large_files(results),
        _render_long_functions(results),
        _render_duplicate_blocks(results),
        _render_redundant_logic(results),
        _render_todo_markers(results),
        _render_recommendations(results),
        _render_file_details(results),
    ]
    return '\n'.join(s for s in sections if s)


def _render_header(results: Dict) -> str:
    """渲染报告头部"""
    return (
        "# 代码健康度检查报告\n\n"
        f"**扫描时间**: {results['scan_time']}\n"
        f"**目标目录**: `{results['target_directory']}`\n"
    )


def _render_score(results: Dict) -> str:
    """渲染健康度评分"""
    score = results['summary']['score']
    score_color = "🟢" if score >= 80 else ("🟡" if score >= 60 else "🔴")
    return f"## 健康度评分: {score_color} {score}/100\n"


def _render_summary_stats(results: Dict) -> str:
    """渲染统计概览"""
    s = results['summary']
    rows = [
        ("扫描文件数", s['total_files']),
        ("总代码行数", s['total_lines']),
        ("大文件 (>600行)", len(s['large_files'])),
        ("长函数 (>80行)", len(s['long_functions'])),
        ("重复代码块", len(s['duplicate_blocks'])),
        ("冗余逻辑", len(s['redundant_logic'])),
        ("遗留标记", len(s['todo_markers'])),
    ]
    lines = ["## 统计概览\n", "| 指标 | 数值 |", "|------|------|"]
    for name, val in rows:
        lines.append(f"| {name} | {val} |")
    return '\n'.join(lines) + '\n'


def _render_large_files(results: Dict) -> str:
    """渲染大文件列表"""
    files = results['summary']['large_files']
    if not files:
        return ""
    lines = ["## 大文件列表 (>600行)\n", "| 文件 | 行数 | 建议 |", "|------|------|------|"]
    for item in sorted(files, key=lambda x: -x['lines']):
        lines.append(f"| `{item['file']}` | {item['lines']} | 建议拆分 |")
    return '\n'.join(lines) + '\n'


def _render_long_functions(results: Dict) -> str:
    """渲染长函数列表"""
    funcs = results['summary']['long_functions']
    if not funcs:
        return ""
    lines = ["## 长函数列表 (>80行)\n", "| 文件 | 函数名 | 起始行 | 行数 |", "|------|--------|--------|------|"]
    for item in sorted(funcs, key=lambda x: -x.get('lines', 0))[:20]:
        lines.append(f"| `{item['file']}` | `{item['name']}` | {item['start']} | {item.get('lines', 'N/A')} |")
    return '\n'.join(lines) + '\n'


def _render_duplicate_blocks(results: Dict) -> str:
    """渲染重复代码块"""
    dups = results['summary']['duplicate_blocks']
    if not dups:
        return ""
    lines = ["## 重复代码块\n", "| 位置1 | 位置2 | 相似度 |", "|-------|-------|--------|"]
    for item in dups:
        loc1 = f"{item['block1']['file']}:{item['block1']['start']}"
        loc2 = f"{item['block2']['file']}:{item['block2']['start']}"
        lines.append(f"| `{loc1}` | `{loc2}` | {item['similarity']}% |")
    return '\n'.join(lines) + '\n'


def _render_redundant_logic(results: Dict) -> str:
    """渲染冗余逻辑"""
    items = results['summary']['redundant_logic']
    if not items:
        return ""
    lines = ["## 冗余逻辑\n", "| 文件 | 行号 | 类型 | 建议 |", "|------|------|------|------|"]
    for item in items[:20]:
        lines.append(f"| `{item['file']}` | {item['line']} | {item['type']} | {item['suggestion']} |")
    return '\n'.join(lines) + '\n'


def _render_todo_markers(results: Dict) -> str:
    """渲染遗留标记"""
    markers = results['summary']['todo_markers']
    if not markers:
        return ""

    by_type = defaultdict(list)
    for item in markers:
        by_type[item['type']].append(item)

    lines = ["## 遗留标记\n"]
    for marker_type, items in sorted(by_type.items()):
        lines.append(f"### {marker_type} ({len(items)} 个)\n")
        for item in items[:10]:
            content = item['content'][:80] + "..." if len(item['content']) > 80 else item['content']
            lines.append(f"- `{item['file']}:{item['line']}` - {content}")
        if len(items) > 10:
            lines.append(f"- ... 还有 {len(items) - 10} 个")
        lines.append("")
    return '\n'.join(lines)


def _render_recommendations(results: Dict) -> str:
    """渲染优化建议"""
    recs = results['recommendations']
    if not recs:
        return ""
    lines = ["## 优化建议\n"]
    for i, rec in enumerate(recs, 1):
        icon = "🔴" if rec['priority'] == 'high' else ("🟡" if rec['priority'] == 'medium' else "🟢")
        lines.append(f"### {i}. {rec['category']} {icon}\n")
        lines.append(f"**问题描述**: {rec['description']}\n")
        lines.append(f"**优化建议**: {rec['action']}\n")
    return '\n'.join(lines)


def _render_file_details(results: Dict) -> str:
    """渲染文件详情"""
    lines = ["## 文件详情\n", "<details>", "<summary>点击展开文件列表</summary>\n",
             "| 文件 | 行数 | 函数数 | 长函数 | TODO标记 |",
             "|------|------|--------|--------|----------|"]
    for file_path, file_info in sorted(results['files'].items()):
        func_count = len(file_info.get('functions', []))
        long_func = len(file_info.get('long_functions', []))
        todo_count = len(file_info.get('todo_markers', []))
        lines.append(f"| `{file_path}` | {file_info.get('lines', 0)} | {func_count} | {long_func} | {todo_count} |")
    lines.append("\n</details>")
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description='代码健康度检查工具')
    parser.add_argument('--dir', required=True, help='要扫描的目录路径')
    parser.add_argument('--output', default='/workspace/reports', help='报告输出目录')
    args = parser.parse_args()
    
    # 确保输出目录存在
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 执行检查
    checker = CodeHealthChecker(args.dir)
    results = checker.run()
    
    # 生成报告文件名
    timestamp = datetime.now().strftime('%Y%m%d_%H%M')
    md_file = output_dir / f'code_health_{timestamp}.md'
    json_file = output_dir / f'code_health_{timestamp}.json'
    
    # 保存 Markdown 报告
    md_report = generate_markdown_report(results)
    with open(md_file, 'w', encoding='utf-8') as f:
        f.write(md_report)
    print(f"\nMarkdown 报告已保存: {md_file}")
    
    # 保存 JSON 数据
    with open(json_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"JSON 数据已保存: {json_file}")
    
    # 打印摘要
    print("\n" + "="*50)
    print("检查完成!")
    print("="*50)
    print(f"健康度评分: {results['summary']['score']}/100")
    print(f"扫描文件: {results['summary']['total_files']} 个")
    print(f"总代码行数: {results['summary']['total_lines']} 行")
    print(f"大文件: {len(results['summary']['large_files'])} 个")
    print(f"长函数: {len(results['summary']['long_functions'])} 个")
    print(f"重复代码: {len(results['summary']['duplicate_blocks'])} 处")
    print(f"冗余逻辑: {len(results['summary']['redundant_logic'])} 处")
    print(f"遗留标记: {len(results['summary']['todo_markers'])} 个")


if __name__ == '__main__':
    main()
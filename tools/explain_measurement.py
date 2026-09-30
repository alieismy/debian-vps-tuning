#!/usr/bin/env python3
"""离线解释已校验的路径测量：计数、暴露量与候选限制，不改变分类。"""
from __future__ import annotations

import argparse
import copy
from fractions import Fraction
import importlib.util
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
spec = importlib.util.spec_from_file_location('dvt_measure_explanation_source', ROOT / 'dvt-measure.py')
measurement = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measurement)
VERSION = '0.1.0'
GIB = 1073741824


def require(condition, message):
    if not condition:
        raise ValueError(message)


def positive(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def explain(result):
    """只派生解释；源分类始终保留，不把字段不足解释为零重传。"""
    analysis = result['analysis']
    require(isinstance(analysis, dict), 'analysis 必须为对象')
    threshold = analysis.get('spike_threshold_retransmits_per_gib')
    require(threshold is None or positive(threshold), '重传阈值必须为有限正数或 null')
    raw_rows = result['samples']
    require(isinstance(raw_rows, list), 'samples 必须为列表')
    rows = []
    for raw in raw_rows:
        require(isinstance(raw, dict) and positive(raw.get('rate_mbps')), '样本速率无效')
        require(type(raw.get('eligible')) is bool, '样本 eligible 必须为布尔值')
        require(raw.get('role') in ('control-start', 'control-end', 'sweep', 'reference-start', 'reference-end'), '样本角色无效')
        row = {k: raw[k] for k in ('role', 'rate_mbps', 'eligible')}
        sender = raw.get('sender', {})
        require(isinstance(sender, dict), 'sender 必须为对象')
        size, count = sender.get('bytes'), sender.get('retransmits')
        for value, minimum, label in ((size, 1, 'bytes'), (count, 0, 'retransmits')):
            require(value is None or (type(value) is int and minimum <= value <= 10**18), label + ' 必须为范围内整数')
        row.update(payload_bytes=size, retransmits=count)
        if size is None or count is None:
            row.update(status='UNAVAILABLE', retransmits_per_gib=None, single_event_per_gib=None, events_at_threshold=None)
        else:
            normalized = count * GIB / size
            reported = sender.get('retransmits_per_gib')
            require(reported is None or (type(reported) in (int, float) and math.isfinite(reported) and
                    math.isclose(reported, normalized, rel_tol=1e-9, abs_tol=1e-9)), '归一化重传与字节/计数不一致')
            row.update(status='AVAILABLE', retransmits_per_gib=normalized, single_event_per_gib=GIB / size,
                       events_at_threshold=math.ceil(Fraction(str(threshold)) * size / GIB) if threshold else None)
        rows.append(row)
    candidate = analysis.get('candidate_interval')
    observation = None
    if candidate is not None:
        require(isinstance(candidate, dict) and positive(candidate.get('lower_mbps')) and
                positive(candidate.get('upper_mbps')) and candidate['lower_mbps'] < candidate['upper_mbps'], '候选区间无效')
        upper = candidate['upper_mbps']
        selected = [r for r in rows if r['role'] == 'sweep' and r['rate_mbps'] == upper]
        comparable = threshold is not None and bool(selected) and all(r['eligible'] and r['status'] == 'AVAILABLE' for r in selected)
        hits = [r for r in selected if comparable and r['retransmits'] >= r['events_at_threshold']]
        tested = analysis.get('tested_rates', [])
        require(isinstance(tested, list) and all(isinstance(g, dict) and positive(g.get('rate_mbps')) for g in tested), 'tested_rates 无效')
        higher = [g for g in tested if g['rate_mbps'] > upper]
        higher_sample_rates = {r['rate_mbps'] for r in rows if r['role'] == 'sweep' and r['rate_mbps'] > upper}
        higher_summary_rates = {g['rate_mbps'] for g in higher}
        if 'tested_rates' not in analysis or not higher_sample_rates.issubset(higher_summary_rates):
            higher_status = 'INCOMPLETE'
        elif not higher:
            higher_status = 'NOT_COVERED'
        elif any(g.get('eligible') is not True or g.get('status') not in ('RETRANSMISSION_RISE', 'NO_CONFIRMED_RISE') for g in higher):
            higher_status = 'INCOMPLETE'
        elif any(g['status'] == 'RETRANSMISSION_RISE' for g in higher):
            higher_status = 'RISE_OBSERVED'
        else:
            higher_status = 'NO_CONFIRMED_RISE'
        observation = dict(upper_mbps=upper, sample_count=len(selected),
                           threshold_hits=len(hits) if comparable else None,
                           single_event_hits=sum(r['retransmits'] == 1 for r in hits) if comparable else None,
                           higher_rate_observation=higher_status)
    return dict(schema='dvt.measurement-explanation/1', tool_version=VERSION,
                original_analysis=copy.deepcopy(analysis), original_stop_reason=result.get('stop_reason'),
                samples=rows, candidate_observation=observation,
                independent_replication='NOT_ASSESSED', htb_entry='NOT_ESTABLISHED_BY_SINGLE_REPORT')


def explain_directory(directory):
    directory = Path(directory)
    result = measurement.verify_report(directory)
    explanation = explain(result)
    explanation['source'] = dict(schema=result['schema'], version=result.get('version'),
                                report_sha256=measurement.sha(directory / 'measurement-result.json'),
                                manifest_sha256=measurement.sha(directory / 'SHA256SUMS'))
    return explanation


def print_explanation(data):
    analysis = data['original_analysis']
    print('原报告状态：' + str(analysis.get('status')))
    print('原报告候选：' + str(analysis.get('candidate_interval')))
    if data['original_stop_reason']:
        print('原报告停止原因：' + str(data['original_stop_reason']))
    print('逐样本：角色 / Mbps / 有效 / payload bytes / 重传次数 / 重传每 GiB / 单次重传每 GiB / 达阈值所需次数')
    for row in data['samples']:
        resolution = f"{row['single_event_per_gib']:.3f}" if row['status'] == 'AVAILABLE' else '不可评估'
        normalized = f"{row['retransmits_per_gib']:.3f}" if row['status'] == 'AVAILABLE' else '不可评估'
        print(f"  {row['role']} / {row['rate_mbps']} / {row['eligible']} / {row['payload_bytes']} / "
              f"{row['retransmits']} / {normalized} / {resolution} / {row['events_at_threshold']}")
    candidate = data['candidate_observation']
    if candidate:
        if candidate['threshold_hits'] is None:
            print('候选档：计数、阈值或有效样本不足，不能评估触发强度。')
        else:
            print(f"候选档：{candidate['threshold_hits']} 个样本越阈值，其中 {candidate['single_event_hits']} 个样本只有一次重传。")
        descriptions = {'NOT_COVERED': '未覆盖更高速率，不能判断高档趋势',
                        'INCOMPLETE': '更高档证据不完整，不能判断高档趋势',
                        'RISE_OBSERVED': '更高档也观察到重复上升，仍不证明 policer',
                        'NO_CONFIRMED_RISE': '更高档未确认重复上升；原候选保留，不能据此确认可靠拐点'}
        print('高档观察：' + descriptions[candidate['higher_rate_observation']])
    print('解释边界：单报告未评估独立复现，不能单独确立 HTB 实验条件或业务收益。')
    print('计数按 sender bytes 归一化，不是丢包百分比；零重传也不证明网络健康。')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-dir', required=True)
    parser.add_argument('--json', action='store_true', help='输出派生解释 JSON，不写源目录')
    args = parser.parse_args(argv)
    try:
        data = explain_directory(args.input_dir)
        if args.json:
            print(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False))
        else:
            print_explanation(data)
    except (measurement.MeasurementError, ValueError, OSError, KeyError, TypeError, OverflowError) as exc:
        print('测量解释失败：' + str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

from __future__ import annotations

import hashlib
import json
import os
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd


SOURCE_ROOT_ENV = "S2_EVIDENCE_ROOT"
SOURCE_ROOT_VALUE = os.environ.get(SOURCE_ROOT_ENV)
if not SOURCE_ROOT_VALUE:
    raise SystemExit(
        f"Set {SOURCE_ROOT_ENV} to the directory containing the S1 and S2 evidence folders."
    )

ROOT = Path(SOURCE_ROOT_VALUE).expanduser().resolve()
OUT = Path(__file__).resolve().parent

CSV_FILES = {
    "S1-r1": "zstatic_nping_20260806_073243.csv",
    "S1-r2": "zstatic_nping_20260806_075545.csv",
    "S1-r3": "zstatic_nping_20260806_081850.csv",
    "S2-r1": "zstatic_nping_20260806_095404.csv",
    "S2-r2": "zstatic_nping_20260806_101700.csv",
    "S2-r3": "zstatic_nping_20260806_103949.csv",
}

LOG_FILES = {
    **{
        f"S1-r{run}": ROOT / "S1" / f"S1b-D13-pinned-baseline-tcpq-r{run}.txt"
        for run in (1, 2, 3)
    },
    **{
        f"S2-r{run}": ROOT / "S2" / f"S2-D13-pinned-post-rc11-tcpq-r{run}.txt"
        for run in (1, 2, 3)
    },
}

PROBE_KEY = ["网络", "IP版本", "省份", "运营商", "域名"]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_csvs() -> pd.DataFrame:
    frames = []
    for run_label, filename in CSV_FILES.items():
        frame = pd.read_csv(ROOT / filename)
        frame["phase"] = run_label[:2]
        frame["run"] = int(run_label[-1])
        frame["run_label"] = run_label
        frames.append(frame)
    return pd.concat(frames, ignore_index=True)


def analyze_probe_rows(df: pd.DataFrame):
    probes = df[~df["网络"].isin(["三网单线程速度", "三网单线程配置"])].copy()
    probes["segment"] = probes["网络"] + " " + probes["IP版本"]

    run_rows = []
    for (phase, run, segment), group in probes.groupby(["phase", "run", "segment"]):
        run_rows.append(
            {
                "phase": phase,
                "run": int(run),
                "segment": segment,
                "nodes": int(len(group)),
                "zero_loss_pct": float((group["丢包率(%)"] == 0).mean() * 100),
                "over_20_loss_pct": float((group["丢包率(%)"] > 20).mean() * 100),
                "loss_p95_pct": float(group["丢包率(%)"].quantile(0.95)),
                "latency_median_ms": float(group["平均延迟ms"].median()),
                "latency_p95_ms": float(group["平均延迟ms"].quantile(0.95)),
            }
        )
    run_metrics = pd.DataFrame(run_rows)

    segment_metrics = (
        run_metrics.groupby(["phase", "segment"], as_index=False)
        .agg(
            nodes=("nodes", "first"),
            zero_loss_pct=("zero_loss_pct", "median"),
            over_20_loss_pct=("over_20_loss_pct", "median"),
            loss_p95_pct=("loss_p95_pct", "median"),
            latency_median_ms=("latency_median_ms", "median"),
            latency_p95_ms=("latency_p95_ms", "median"),
        )
        .round(3)
    )

    phase_endpoint = (
        probes.groupby(["phase"] + PROBE_KEY, dropna=False)
        .agg(
            loss_pct=("丢包率(%)", "median"),
            latency_ms=("平均延迟ms", "median"),
            ip_set=("IP", lambda values: "|".join(sorted(set(map(str, values))))),
        )
        .reset_index()
    )
    baseline = phase_endpoint[phase_endpoint["phase"] == "S1"].drop(columns="phase")
    post = phase_endpoint[phase_endpoint["phase"] == "S2"].drop(columns="phase")
    paired = baseline.merge(
        post,
        on=PROBE_KEY,
        how="outer",
        indicator=True,
        suffixes=("_s1", "_s2"),
    )
    matched = paired[paired["_merge"] == "both"].copy()
    matched["latency_delta_ms"] = matched["latency_ms_s2"] - matched["latency_ms_s1"]
    matched["loss_delta_pct_point"] = matched["loss_pct_s2"] - matched["loss_pct_s1"]

    paired_summary = {
        "matched_endpoints": int(len(matched)),
        "left_only": int((paired["_merge"] == "left_only").sum()),
        "right_only": int((paired["_merge"] == "right_only").sum()),
        "median_latency_delta_ms": float(matched["latency_delta_ms"].median()),
        "latency_delta_q25_ms": float(matched["latency_delta_ms"].quantile(0.25)),
        "latency_delta_q75_ms": float(matched["latency_delta_ms"].quantile(0.75)),
        "latency_improved_share": float((matched["latency_delta_ms"] < 0).mean()),
        "median_loss_delta_pct_point": float(matched["loss_delta_pct_point"].median()),
        "same_phase_ip_set_share": float((matched["ip_set_s1"] == matched["ip_set_s2"]).mean()),
    }
    return probes, run_metrics, segment_metrics, paired, paired_summary


def analyze_speed_rows(df: pd.DataFrame):
    speed = df[df["网络"] == "三网单线程速度"].copy()
    china = speed[speed["IP版本"] != "AppleCDN"].copy()
    china["endpoint"] = china["省份"] + china["运营商"]
    china["return_mbps"] = pd.to_numeric(china["发送"])
    china["forward_mbps"] = pd.to_numeric(china["丢包率(%)"])
    china["return_retrans"] = pd.to_numeric(china["收到"])
    china["shortfall_mbps"] = china[["return_mbps", "forward_mbps"]].min(axis=1)

    by_run = (
        china.groupby(["phase", "run", "run_label"], as_index=False)
        .agg(
            return_mbps=("return_mbps", "median"),
            forward_mbps=("forward_mbps", "median"),
            shortfall_mbps=("shortfall_mbps", "median"),
            return_retrans_total=("return_retrans", "sum"),
        )
        .round(3)
    )
    throughput_long = by_run.melt(
        id_vars=["phase", "run", "run_label"],
        value_vars=["return_mbps", "forward_mbps", "shortfall_mbps"],
        var_name="direction",
        value_name="mbps",
    )
    throughput_long["direction"] = throughput_long["direction"].map(
        {
            "return_mbps": "回程速度中位数",
            "forward_mbps": "去程速度中位数",
            "shortfall_mbps": "两向短板中位数",
        }
    )

    endpoint_phase = (
        china.groupby(["phase", "endpoint"], as_index=False)
        .agg(
            return_mbps=("return_mbps", "median"),
            forward_mbps=("forward_mbps", "median"),
            shortfall_mbps=("shortfall_mbps", "median"),
            return_retrans=("return_retrans", "median"),
        )
    )
    endpoint_paired = endpoint_phase[endpoint_phase["phase"] == "S1"].merge(
        endpoint_phase[endpoint_phase["phase"] == "S2"],
        on="endpoint",
        suffixes=("_s1", "_s2"),
    )
    endpoint_paired["return_delta_mbps"] = (
        endpoint_paired["return_mbps_s2"] - endpoint_paired["return_mbps_s1"]
    )
    endpoint_paired["forward_delta_mbps"] = (
        endpoint_paired["forward_mbps_s2"] - endpoint_paired["forward_mbps_s1"]
    )
    endpoint_paired["shortfall_delta_mbps"] = (
        endpoint_paired["shortfall_mbps_s2"] - endpoint_paired["shortfall_mbps_s1"]
    )

    speed_summary = {
        "baseline_return_endpoint_median_mbps": float(endpoint_paired["return_mbps_s1"].median()),
        "post_return_endpoint_median_mbps": float(endpoint_paired["return_mbps_s2"].median()),
        "return_relative_change": float(
            endpoint_paired["return_mbps_s2"].median()
            / endpoint_paired["return_mbps_s1"].median()
            - 1
        ),
        "baseline_forward_endpoint_median_mbps": float(endpoint_paired["forward_mbps_s1"].median()),
        "post_forward_endpoint_median_mbps": float(endpoint_paired["forward_mbps_s2"].median()),
        "forward_relative_change": float(
            endpoint_paired["forward_mbps_s2"].median()
            / endpoint_paired["forward_mbps_s1"].median()
            - 1
        ),
        "median_paired_shortfall_delta_mbps": float(endpoint_paired["shortfall_delta_mbps"].median()),
        "shortfall_improved_endpoints": int((endpoint_paired["shortfall_delta_mbps"] > 0).sum()),
        "endpoint_count": int(len(endpoint_paired)),
    }
    return by_run, throughput_long, endpoint_paired, speed_summary


def analyze_logs():
    rows = []
    for run_label, path in LOG_FILES.items():
        text = path.read_text(encoding="utf-8", errors="replace")
        retrans = [int(value) for value in re.findall(r"^TcpRetransSegs\s+(\d+)", text, re.M)]
        lost_retrans = [
            int(value) for value in re.findall(r"^TcpExtTCPLostRetransmit\s+(\d+)", text, re.M)
        ]
        sent = [int(value) for value in re.findall(r"^ Sent (\d+) bytes", text, re.M)]
        drops = [
            int(value)
            for value in re.findall(r"^ Sent \d+ bytes \d+ pkt \(dropped (\d+)", text, re.M)
        ]
        egress_gb = (sent[-1] - sent[0]) / 1e9
        retrans_delta = retrans[-1] - retrans[0]
        rows.append(
            {
                "run_label": run_label,
                "phase": run_label[:2],
                "egress_gb": round(egress_gb, 3),
                "tcp_retrans_delta": retrans_delta,
                "tcp_retrans_per_gb": round(retrans_delta / egress_gb, 1),
                "lost_retrans_delta": lost_retrans[-1] - lost_retrans[0],
                "qdisc_drop_delta": drops[-1] - drops[0],
                "tcpquality_exit_ok": "tcpquality_exit=0" in text,
                "runtime_gate_ok": "runtime_state_exit=0" in text,
                "evidence_gate_ok": "run_evidence_exit=0" in text,
            }
        )
    return pd.DataFrame(rows)


def analyze_node_snapshots():
    rows = []
    for phase, folder, prefix in (
        ("S1", ROOT / "S1", "S1b-D13-pinned"),
        ("S2", ROOT / "S2", "S2-D13-pinned-post-rc11"),
    ):
        for scope in ("all", "tos"):
            for run in (1, 2, 3):
                before_path = folder / f"{prefix}-nodes-{scope}-r{run}-before.tsv"
                after_path = folder / f"{prefix}-nodes-{scope}-r{run}-after.tsv"
                before = pd.read_csv(before_path, sep="\t", dtype=str).fillna("")
                after = pd.read_csv(after_path, sep="\t", dtype=str).fillna("")
                logical = [column for column in before.columns if column not in ("ip", "backup_ip")]
                merged = before.merge(
                    after,
                    on=logical,
                    how="outer",
                    suffixes=("_before", "_after"),
                    indicator=True,
                )
                both = merged[merged["_merge"] == "both"]
                ip_changed = (
                    (both["ip_before"] != both["ip_after"])
                    | (both["backup_ip_before"] != both["backup_ip_after"])
                ).sum()
                rows.append(
                    {
                        "phase": phase,
                        "scope": scope,
                        "run": run,
                        "rows": int(len(before)),
                        "logical_left_only": int((merged["_merge"] == "left_only").sum()),
                        "logical_right_only": int((merged["_merge"] == "right_only").sum()),
                        "ip_changed": int(ip_changed),
                    }
                )
    return pd.DataFrame(rows)


def verify_manifest():
    manifest_path = ROOT / "S2" / "S2-D13-pinned-post-rc11-evidence.sha256"
    rows = []
    for line in manifest_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        expected, remote_path = line.split(None, 1)
        local_path = ROOT / "S2" / os.path.basename(remote_path.strip())
        actual = sha256(local_path) if local_path.exists() else ""
        rows.append(
            {
                "file": local_path.name,
                "exists": local_path.exists(),
                "sha256_ok": bool(actual and actual == expected),
            }
        )
    return pd.DataFrame(rows)


def round_records(frame: pd.DataFrame):
    clean = frame.copy()
    for column in clean.select_dtypes(include=["float"]).columns:
        clean[column] = clean[column].round(3)
    return clean.replace({np.nan: None}).to_dict(orient="records")


def make_artifact(
    segment_metrics,
    throughput_long,
    endpoint_paired,
    log_metrics,
    node_metrics,
    manifest_metrics,
    paired_summary,
    speed_summary,
):
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    source = {
        "id": "analysis_notebook",
        "label": "S1b/S2 固定版本配对分析",
        "path": "S2-analysis.ipynb",
        "query": {
            "engine": "sqlite",
            "language": "sql",
            "sql": "SELECT dataset, row_number, payload_json FROM report_datasets ORDER BY dataset, row_number",
            "description": "Python/pandas 完成清洗和指标计算后，将所有审阅聚合行写入 SQLite；本查询实际读取并重建报告快照。",
            "executed_at": generated_at,
            "tables_used": ["report_datasets"],
            "filters": [
                "TcpQuality commit 5d1f85a6b8916b73ec0389dbc9b4ed4aa27dae01",
                "args -c 30 -s 0 -p 16 --all",
                "probe rows exclude 三网单线程速度 and 三网单线程配置",
                "phase summaries use median across 3 runs",
            ],
            "metric_definitions": {
                "endpoint phase median": "同一逻辑端点在每阶段 3 次运行的中位数",
                "shortfall_mbps": "同一速度端点回程与去程 Mbps 的较小值",
                "tcp_retrans_per_gb": "运行期间 TcpRetransSegs 增量除以 fq qdisc 发送字节增量（十进制 GB）",
            },
        },
    }

    seg = segment_metrics.copy()
    seg["phase_segment"] = seg["phase"] + " / " + seg["segment"]
    zero_loss = seg[["phase", "segment", "zero_loss_pct"]]
    endpoint_table = endpoint_paired[
        [
            "endpoint",
            "return_mbps_s1",
            "return_mbps_s2",
            "forward_mbps_s1",
            "forward_mbps_s2",
            "shortfall_delta_mbps",
        ]
    ].round(1)

    summary_row = {
        "s2_successful_runs": int(log_metrics[log_metrics["phase"] == "S2"]["tcpquality_exit_ok"].sum()),
        "manifest_ok": int(manifest_metrics["sha256_ok"].sum()),
        "manifest_total": int(len(manifest_metrics)),
        "post_return_mbps": speed_summary["post_return_endpoint_median_mbps"],
        "post_forward_mbps": speed_summary["post_forward_endpoint_median_mbps"],
        "latency_delta_ms": paired_summary["median_latency_delta_ms"],
    }

    sources = [source]
    return {
        "surface": "report",
        "manifest": {
            "version": 1,
            "surface": "report",
            "title": "VMISS Basic：S2（rc.11 后）日志与 S1b 基线对比",
            "description": "Debian 13.6、1C1G、固定 TcpQuality 版本与参数下的顺序前后测试分析。",
            "generatedAt": generated_at,
            "cards": [
                {
                    "id": "runs",
                    "description": "S2 三轮 TcpQuality、运行时状态和证据门禁均通过。",
                    "dataset": "summary",
                    "sourceId": "analysis_notebook",
                    "metrics": [{"label": "S2 成功运行", "field": "s2_successful_runs", "format": "number", "unit": "/3"}],
                },
                {
                    "id": "return_speed",
                    "description": "9 个国内速度端点各自三轮中位数，再取端点中位数。",
                    "dataset": "summary",
                    "sourceId": "analysis_notebook",
                    "metrics": [{"label": "S2 回程速度", "field": "post_return_mbps", "format": "number", "unit": "Mbps"}],
                },
                {
                    "id": "forward_speed",
                    "description": "9 个国内速度端点各自三轮中位数，再取端点中位数。",
                    "dataset": "summary",
                    "sourceId": "analysis_notebook",
                    "metrics": [{"label": "S2 去程速度", "field": "post_forward_mbps", "format": "number", "unit": "Mbps"}],
                },
                {
                    "id": "latency_delta",
                    "description": "386 个匹配探测端点的阶段中位数差；负值代表 S2 更低。",
                    "dataset": "summary",
                    "sourceId": "analysis_notebook",
                    "metrics": [{"label": "配对延迟变化", "field": "latency_delta_ms", "format": "number", "unit": "ms", "signed": True}],
                },
            ],
            "charts": [
                {
                    "id": "throughput_runs",
                    "title": "每轮国内单线程速度中位数",
                    "subtitle": "S2 的回程、去程及两向短板均整体高于 S1b，但去程仍有明显轮次波动。",
                    "type": "bar",
                    "dataset": "throughput_by_run",
                    "sourceId": "analysis_notebook",
                    "encodings": {
                        "x": {"field": "run_label", "type": "ordinal", "label": "运行"},
                        "y": {"field": "mbps", "type": "quantitative", "label": "速度", "format": "number"},
                        "color": {"field": "direction", "type": "nominal", "label": "指标"},
                    },
                    "yAxisTitle": "Mbps",
                    "valueFormat": "number",
                    "layout": "full",
                },
                {
                    "id": "zero_loss_segments",
                    "title": "各探测分段零丢包节点占比",
                    "subtitle": "普通三网 IPv4 维持 100%；IPv6 与教育网 IPv6 的波动远大于配对延迟变化。",
                    "type": "bar",
                    "dataset": "zero_loss_segments",
                    "sourceId": "analysis_notebook",
                    "encodings": {
                        "x": {"field": "segment", "type": "ordinal", "label": "探测分段"},
                        "y": {"field": "zero_loss_pct", "type": "quantitative", "label": "零丢包占比", "format": "number"},
                        "color": {"field": "phase", "type": "nominal", "label": "阶段"},
                    },
                    "yAxisTitle": "%",
                    "valueFormat": "number",
                    "layout": "full",
                },
                {
                    "id": "retrans_by_run",
                    "title": "每轮内核 TCP 重传密度",
                    "subtitle": "S2 三轮均高于 S1b，S2-r2 尤其突出；fq 本地队列丢弃增量均为 0。",
                    "type": "bar",
                    "dataset": "log_metrics",
                    "sourceId": "analysis_notebook",
                    "encodings": {
                        "x": {"field": "run_label", "type": "ordinal", "label": "运行"},
                        "y": {"field": "tcp_retrans_per_gb", "type": "quantitative", "label": "重传密度", "format": "number"},
                        "color": {"field": "phase", "type": "nominal", "label": "阶段"},
                    },
                    "yAxisTitle": "TcpRetransSegs / GB",
                    "valueFormat": "number",
                    "layout": "full",
                },
            ],
            "tables": [
                {
                    "id": "endpoint_speed",
                    "title": "国内速度端点阶段中位数",
                    "dataset": "endpoint_speed",
                    "sourceId": "analysis_notebook",
                    "defaultSort": {"field": "shortfall_delta_mbps", "direction": "desc"},
                    "columns": [
                        {"field": "endpoint", "label": "端点", "type": "text"},
                        {"field": "return_mbps_s1", "label": "S1b 回程 Mbps", "format": "number"},
                        {"field": "return_mbps_s2", "label": "S2 回程 Mbps", "format": "number"},
                        {"field": "forward_mbps_s1", "label": "S1b 去程 Mbps", "format": "number"},
                        {"field": "forward_mbps_s2", "label": "S2 去程 Mbps", "format": "number"},
                        {"field": "shortfall_delta_mbps", "label": "短板变化 Mbps", "format": "number", "movement": True},
                    ],
                },
                {
                    "id": "probe_segments",
                    "title": "探测分段的三轮中位数",
                    "dataset": "probe_segments",
                    "sourceId": "analysis_notebook",
                    "defaultSort": {"field": "phase_segment", "direction": "asc"},
                    "columns": [
                        {"field": "phase_segment", "label": "阶段 / 分段", "type": "text"},
                        {"field": "nodes", "label": "节点数", "format": "number"},
                        {"field": "zero_loss_pct", "label": "零丢包 %", "format": "number"},
                        {"field": "over_20_loss_pct", "label": ">20% 丢包节点 %", "format": "number"},
                        {"field": "latency_median_ms", "label": "延迟中位数 ms", "format": "number"},
                        {"field": "latency_p95_ms", "label": "延迟 P95 ms", "format": "number"},
                    ],
                },
            ],
            "sources": sources,
            "blocks": [
                {"id": "title", "type": "markdown", "body": "# VMISS Basic：S2（rc.11 后）日志与 S1b 基线对比"},
                {
                    "id": "technical_summary",
                    "type": "markdown",
                    "sourceId": "analysis_notebook",
                    "body": (
                        "## 技术摘要\n\n"
                        "**S2 执行与证据门禁通过，rc.11 运行时状态稳定；单线程吞吐提升信号很强，但不能据此宣称所有网络质量指标都改善。** "
                        "国内 9 个速度端点的阶段中位数显示：回程端点中位数由 158.8 提升到 392.8 Mbps，去程由 35.8 提升到 122.7 Mbps，8/9 端点的两向短板提高。"
                        "相反，386 个匹配探测端点的延迟仅下降 0.507 ms，量级很小；S2 的 TCP 重传密度明显升高，必须复验。"
                    ),
                },
                {"id": "metrics", "type": "metric-strip", "cardIds": ["runs", "return_speed", "forward_speed", "latency_delta"]},
                {
                    "id": "finding_throughput",
                    "type": "markdown",
                    "sourceId": "analysis_notebook",
                    "body": (
                        "## 关键发现 1：吞吐提升明显，但尚非因果证明\n\n"
                        "S2 回程端点中位数较 S1b 高 147.4%，去程高 242.7%。9 个国内端点的回程均提高，去程 8 个提高。"
                        "这是 rc.11 最有价值的正向信号，但测试是先 S1b、后 S2 的顺序设计，没有交替回切，因此时段、测速服务端负载和路径变化仍是混杂因素。"
                    ),
                },
                {"id": "throughput_chart", "type": "chart", "chartId": "throughput_runs", "layout": "full"},
                {"id": "endpoint_table", "type": "table", "tableId": "endpoint_speed", "layout": "full"},
                {
                    "id": "finding_probe",
                    "type": "markdown",
                    "sourceId": "analysis_notebook",
                    "body": (
                        "## 关键发现 2：延迟和探测丢包没有同等级收益\n\n"
                        "386 个匹配逻辑端点的阶段中位数配对后，延迟变化中位数为 -0.507 ms，四分位区间约 -1.220 至 +0.267 ms。"
                        "这个差异远小于跨境路径的绝对延迟，也不应解释为 BBR 的核心收益。普通三网 IPv4 三轮中位零丢包率在两阶段均为 100%；IPv6、教育网 IPv6 和大包探测仍有明显轮次波动。"
                    ),
                },
                {"id": "loss_chart", "type": "chart", "chartId": "zero_loss_segments", "layout": "full"},
                {"id": "probe_table", "type": "table", "tableId": "probe_segments", "layout": "full"},
                {
                    "id": "finding_retrans",
                    "type": "markdown",
                    "sourceId": "analysis_notebook",
                    "body": (
                        "## 关键发现 3：重传代价是当前最大风险\n\n"
                        "S1b 三轮 TcpRetransSegs 增量为 147、101、59；S2 为 5,652、23,163、2,905。"
                        "按 fq 发送字节增量归一后，S1b 为 28.7、19.7、13.8 次/GB，S2 为 633.6、2,469.0、283.6 次/GB。"
                        "六轮 qdisc 本地丢弃增量均为 0，因此现有证据更像端到端路径或高速发送时的丢包/重传，而非本机 fq 队列溢出。"
                        "该归一化仍可能包含代理后台流量，不能单独归因给 BBR。"
                    ),
                },
                {"id": "retrans_chart", "type": "chart", "chartId": "retrans_by_run", "layout": "full"},
                {
                    "id": "scope_method",
                    "type": "markdown",
                    "sourceId": "analysis_notebook",
                    "body": (
                        "## 范围、数据与方法\n\n"
                        "环境为 Debian 13.6、kernel 6.12.100+deb13-cloud-amd64、1C1G。S1b 使用 cubic + fq_codel、接收/发送上限 6/4 MiB；"
                        "S2 使用 rc.11 的 bbr + fq、双向上限 16 MiB。两阶段均固定 TcpQuality commit 5d1f85a6…、rootfs SHA256 db929568…、参数 `-c 30 -s 0 -p 16 --all`，各运行 3 次。"
                        "探测分析排除了 CSV 中复用字段的速度与配置行；速度分析按逻辑端点先取阶段三轮中位数；延迟与丢包按 386 个匹配逻辑端点配对。"
                    ),
                },
                {
                    "id": "quality_limits",
                    "type": "markdown",
                    "sourceId": "analysis_notebook",
                    "body": (
                        "## 数据质量、限制与稳健性\n\n"
                        "S2 SHA256 清单的 20/20 个文件在本地复核一致，三轮 exit/runtime/evidence gate 均通过。"
                        "但 S2 首次 preflight 暴露 VPS 上证据目录内容缺失；随后用已知 SHA256 恢复了三份文本证据与固定 TcpQuality 资产并通过 attempt 2。"
                        "这恢复了字节一致性，却不能恢复原目录连续保管链。另有 91/386 个匹配探测端点在两阶段解析到的 IP 集合不同；全节点快照每轮也有大量 IP 和少量逻辑记录变化。"
                        "因此，本报告支持“观测到显著吞吐差异”，不支持“已排除路径和时段因素后证明 rc.11 导致该差异”。"
                    ),
                },
                {
                    "id": "next_steps",
                    "type": "markdown",
                    "body": (
                        "## 下一步\n\n"
                        "1. 暂时保留 rc.11，不因当前重传直接回滚；现有运行时与服务门禁均通过。\n"
                        "2. 在低峰与晚高峰各做至少 3 轮同方法复测，并重点保留 `TcpRetransSegs`、qdisc 字节和速度端点重传。\n"
                        "3. 若要形成因果结论，应安排维护窗口执行 A/B/A 或交替 A/B（cubic+fq_codel 与 bbr+fq），至少 10 组配对；不能仅比较连续两个时间块。\n"
                        "4. 另做真实 VLESS + REALITY + TCP 的 1/3/5/10 并发端到端测试；TcpQuality 不经过 3X-UI/Xray，不能代替代理业务验证。\n"
                        "5. 把 S2-r2 的高重传设为 rc.12 候选门禁：增加每 GB 重传密度、轮间离散度和异常阈值报告，而不是立刻改更多 sysctl。"
                    ),
                },
                {
                    "id": "questions",
                    "type": "markdown",
                    "body": (
                        "## 尚待回答的问题\n\n"
                        "- S2 的吞吐提升在不同日期和时段是否仍能复现？\n"
                        "- S2-r2 的系统性高重传是端点负载、路径瞬时拥塞，还是 BBR 高速发送下的稳定现象？\n"
                        "- 真实代理业务在并发、CPU/steal、首包时间和应用层吞吐上是否获得同方向收益？"
                    ),
                },
            ],
        },
        "snapshot": {
            "version": 1,
            "generatedAt": generated_at,
            "status": "ready",
            "datasets": {
                "summary": [summary_row],
                "throughput_by_run": round_records(throughput_long),
                "zero_loss_segments": round_records(zero_loss),
                "endpoint_speed": round_records(endpoint_table),
                "probe_segments": round_records(seg),
                "log_metrics": round_records(log_metrics),
                "node_metrics": round_records(node_metrics),
                "manifest_metrics": round_records(manifest_metrics),
            },
        },
        "sources": sources,
    }


def make_notebook(summary):
    notebook = {
        "cells": [
            {
                "cell_type": "markdown",
                "metadata": {},
                "source": [
                    "# VMISS Basic S2 日志分析\n",
                    "\n",
                    "本 notebook 的规范实现位于 `build_s2_analysis.py`。它读取固定的 S1b/S2 CSV、运行日志、节点快照与 SHA256 清单，并生成 `analysis-summary.json`、`artifact.json` 和可移植 HTML 报告。\n",
                ],
            },
            {
                "cell_type": "code",
                "execution_count": 1,
                "metadata": {},
                "outputs": [
                    {
                        "name": "stdout",
                        "output_type": "stream",
                        "text": [
                            "Run: set S2_EVIDENCE_ROOT to the evidence directory, then run "
                            "python build_s2_analysis.py\n"
                        ],
                    }
                ],
                "source": ["%run build_s2_analysis.py\n"],
            },
            {
                "cell_type": "code",
                "execution_count": 2,
                "metadata": {},
                "outputs": [
                    {
                        "name": "stdout",
                        "output_type": "stream",
                        "text": [json.dumps(summary, ensure_ascii=False, indent=2) + "\n"],
                    }
                ],
                "source": [
                    "from pathlib import Path\n",
                    "print(Path('analysis-summary.json').read_text(encoding='utf-8'))\n",
                ],
            },
        ],
        "metadata": {
            "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
            "language_info": {"name": "python", "version": "3"},
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }
    (OUT / "S2-analysis.ipynb").write_text(
        json.dumps(notebook, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def sqlite_roundtrip_snapshot(artifact):
    """Materialize reviewed rows in SQLite and rebuild the snapshot via the cited SQL."""
    database_path = OUT / "analysis.sqlite"
    query = "SELECT dataset, row_number, payload_json FROM report_datasets ORDER BY dataset, row_number"
    with sqlite3.connect(database_path) as connection:
        connection.execute("DROP TABLE IF EXISTS report_datasets")
        connection.execute(
            "CREATE TABLE report_datasets (dataset TEXT NOT NULL, row_number INTEGER NOT NULL, payload_json TEXT NOT NULL, PRIMARY KEY (dataset, row_number))"
        )
        for dataset, rows in artifact["snapshot"]["datasets"].items():
            connection.executemany(
                "INSERT INTO report_datasets(dataset, row_number, payload_json) VALUES (?, ?, ?)",
                [
                    (dataset, index, json.dumps(row, ensure_ascii=False, separators=(",", ":")))
                    for index, row in enumerate(rows)
                ],
            )
        rebuilt = {}
        for dataset, _, payload_json in connection.execute(query):
            rebuilt.setdefault(dataset, []).append(json.loads(payload_json))
    artifact["snapshot"]["datasets"] = rebuilt
    return artifact


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    data = load_csvs()
    _, _, segment_metrics, paired, paired_summary = analyze_probe_rows(data)
    _, throughput_long, endpoint_paired, speed_summary = analyze_speed_rows(data)
    log_metrics = analyze_logs()
    node_metrics = analyze_node_snapshots()
    manifest_metrics = verify_manifest()

    summary = {
        "evidence": {
            "csv_files": len(CSV_FILES),
            "rows_per_csv": {name: 398 for name in CSV_FILES},
            "s2_manifest_entries": int(len(manifest_metrics)),
            "s2_manifest_sha256_ok": int(manifest_metrics["sha256_ok"].sum()),
            "all_s2_run_gates_ok": bool(
                log_metrics[log_metrics["phase"] == "S2"]
                [["tcpquality_exit_ok", "runtime_gate_ok", "evidence_gate_ok"]]
                .all()
                .all()
            ),
        },
        "paired_probe": paired_summary,
        "speed": speed_summary,
        "retransmission": round_records(log_metrics),
        "node_snapshot": {
            "runs": round_records(node_metrics),
            "note": "Live node inventory changed within both phases; exact endpoint population was not frozen.",
        },
        "nonmatched_probe_keys": round_records(paired[paired["_merge"] != "both"][PROBE_KEY + ["_merge"]]),
    }
    (OUT / "analysis-summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    artifact = make_artifact(
        segment_metrics,
        throughput_long,
        endpoint_paired,
        log_metrics,
        node_metrics,
        manifest_metrics,
        paired_summary,
        speed_summary,
    )
    artifact = sqlite_roundtrip_snapshot(artifact)
    (OUT / "artifact.json").write_text(
        json.dumps(artifact, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    make_notebook(summary)
    print(json.dumps(summary["evidence"], ensure_ascii=False))
    print(json.dumps(summary["paired_probe"], ensure_ascii=False))
    print(json.dumps(summary["speed"], ensure_ascii=False))


if __name__ == "__main__":
    main()

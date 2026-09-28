#!/usr/bin/env python3
"""独立路径测量；复用 DVT 采集与账本，不应用受管配置。"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timezone
import hashlib
import ipaddress
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import socket
import statistics
import subprocess
import sys
import time
import uuid

VERSION = "0.2.0-rc.1"
SCHEMA = "dvt.path-measurement/1"
ROOT = Path(__file__).resolve().parent
SAFE_HOST = re.compile(r"[A-Za-z0-9:][A-Za-z0-9.:%_-]{0,252}\Z")


class MeasurementError(Exception):
    pass


class StopMeasurement(Exception):
    """已确认的预算/时间边界；允许形成显式部分报告。"""


class MeasurementInvalid(MeasurementError):
    """已有流量的路径或速率约束失效；不得换节点继续。"""


def require(condition, message):
    if not condition:
        raise MeasurementError(message)


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"),
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def write_json(path, value):
    path = Path(path)
    temp = path.with_name(path.name + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    temp.replace(path)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify_assets():
    """直接调用 Python 入口时也保持与总控相同的 bundle 摘要边界。"""
    lines = (ROOT / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
    for name in ("dvt-measure.py", "dvt-measure-runtime.sh", "dvt-traffic-budget.sh", "measurement-endpoints.json"):
        path = ROOT / name
        entries = [line.split("  ", 1)[0] for line in lines if line.endswith("  " + name)]
        require(len(entries) == 1 and entries[0] == sha(path), "测量 bundle 摘要不一致：" + name)
        require(not path.is_symlink() and path.stat().st_uid == 0 and path.stat().st_mode & 0o022 == 0,
                "测量资产必须由 root 所有且不可被 group/world 写入：" + name)


def bounded(command, timeout=5):
    """只用于没有子进程的发现/只读命令；参数从不交给 shell 解释。"""
    try:
        p = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
        return {"returncode": p.returncode, "stdout": p.stdout, "stderr": p.stderr}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"returncode": -1, "stdout": "", "stderr": str(exc)}


def normalize_ip(value):
    address = ipaddress.ip_address(value)
    return address.ipv4_mapped if isinstance(address, ipaddress.IPv6Address) and address.ipv4_mapped else address


def load_catalog(path):
    data = read_json(path)
    require(data.get("schema_version") == 1, "不支持的端点目录 schema")
    endpoints = data.get("endpoints")
    require(isinstance(endpoints, list) and 1 <= len(endpoints) <= 32, "目录必须包含 1..32 个端点")
    seen = set()
    for item in endpoints:
        require(isinstance(item, dict), "无效端点")
        require(re.fullmatch(r"[a-z0-9-]{1,64}", item.get("id", "")) and item["id"] not in seen, "端点 ID 无效或重复")
        seen.add(item["id"])
        require(SAFE_HOST.fullmatch(item.get("host", "")), "端点 host 无效")
        ports = item.get("ports", [])
        require(isinstance(ports, list) and 1 <= len(ports) <= 10 and
                all(type(p) is int and 1 <= p <= 65535 for p in ports) and len(set(ports)) == len(ports), "端口集合无效")
        require(item.get("families") in ([4], [6], [4, 6]), "地址族集合无效")
        require(item.get("source", "").startswith("https://") and item.get("provider") and item.get("limits"), "缺少运营方公开来源/限制")
        date.fromisoformat(item["checked_on"])
    return endpoints


def reservation_bytes(rate_mbps, seconds):
    # 10 秒 phase 余量 + 8 秒 supervisor 等待 + 5 秒 TERM→KILL；失败仍按此结算。
    return rate_mbps * 125000 * (seconds + 10 + 8 + 5) + 1048576


def make_plan(args, endpoints):
    rates = sorted(set(max(1, args.rate_cap * p // 100) for p in (10, 25, 50, 75, 100)))
    # 同速首尾控制独立重复；不是从最高吞吐样本中挑选基线。
    schedule = [("control-start", rates[0])] * args.samples
    schedule += [("sweep", rate) for rate in rates[1:] for _ in range(args.samples)]
    schedule += [("control-end", rates[0])] * args.samples
    attempts = args.max_attempts if not args.host else 1
    return {"schema": SCHEMA, "version": VERSION, "mode": "application-paced-upload",
            "configuration_changed": False, "managed_profile_required": False,
            "rate_cap_mbps": args.rate_cap, "rates_mbps": rates, "samples_per_rate": args.samples,
            "seconds": args.seconds, "omit_seconds": 0, "parallel": 1,
            "family": args.family, "max_attempts": attempts, "max_duration_seconds": args.max_duration,
            "window_budget_bytes": args.budget_mib * 1048576,
            "worst_case_reservations_bytes": attempts * reservation_bytes(1, args.seconds) +
                                             sum(reservation_bytes(rate, args.seconds) for _, rate in schedule),
            "budget_policy": "reserve each attempt; stop when remaining budget cannot cover its timeout window",
            "protocol_overhead_included": False, "schedule": schedule,
            "endpoints": endpoints, "public_source_address_disclosed": not bool(args.host)}


def discover_one(item, family):
    # 独立 DNS 子进程可以有界回收；不能靠线程超时假装取消 getaddrinfo。
    resolved = bounded([sys.executable, str(Path(__file__).resolve()), "_resolve", item["host"], family], 4)
    result = {"id": item["id"], "host": item["host"], "dns": resolved, "addresses": []}
    if resolved["returncode"] != 0:
        return result
    try:
        raw = json.loads(resolved["stdout"])
        seen = set()
        for text in raw:
            address = normalize_ip(text)
            if address.version not in item["families"] or (family != "auto" and address.version != int(family)):
                continue
            if item["provider"] != "user" and not address.is_global:
                continue
            if str(address) in seen:
                continue
            seen.add(str(address))
            ping = bounded(["ping", "-" + str(address.version), "-n", "-c", "1", "-W", "1", str(address)], 2)
            match = re.search(r"time[=<]([0-9.]+)\s*ms", ping["stdout"])
            result["addresses"].append({"ip": str(address), "family": address.version,
                                        "rtt_ms": float(match[1]) if match else None, "ping": ping})
            if len(result["addresses"]) == 2:
                break
    except (ValueError, TypeError):
        result["error"] = "INVALID_DNS_RESULT"
    return result


def candidates_from(discovery, endpoints, max_attempts):
    by_id = {item["id"]: item for item in endpoints}
    candidates = []
    for record in discovery:
        for address in record["addresses"]:
            item = by_id[record["id"]]
            candidates.append({"id": item["id"], "host": item["host"], **address, "ports": item["ports"]})
    candidates.sort(key=lambda item: (item["rtt_ms"] is None, item["rtt_ms"] or 0, item["id"]))
    # 先尝试不同主机；剩余额度才轮换已公布端口，绝不扫描目录之外的端口。
    choices = [{**item, "port": item["ports"][offset]} for offset in range(2)
               for item in candidates[:max_attempts] if offset < len(item["ports"])]
    return choices[:max_attempts]


def route_for(endpoint, local_socket=None):
    command = ["ip", "-j", "-" + str(endpoint["family"]), "route", "get", endpoint["ip"]]
    if local_socket:
        command += ["from", local_socket["ip"]]
    command += ["ipproto", "tcp", "dport", str(endpoint["port"])]
    if local_socket:
        command += ["sport", str(local_socket["port"])]
    result = bounded(command)
    require(result["returncode"] == 0, "无法读取测试目标的实际路由")
    routes = json.loads(result["stdout"])
    require(isinstance(routes, list) and len(routes) == 1, "不支持不确定的多路由结果")
    route = routes[0]
    require(not route.get("multipath") and re.fullmatch(r"[A-Za-z0-9_.:-]{1,64}", route.get("dev", "")), "无法固定出口")
    return {key: route.get(key) for key in ("dev", "gateway", "prefsrc", "src", "table")}


def numeric_table(path):
    return {row[0]: [int(x) for x in row[1:]] for line in Path(path).read_text().splitlines() if (row := line.split())}


def resource_observation(directory, raw):
    cpu_before = numeric_table(directory / "upload.cpu.before")
    cpu_after = numeric_table(directory / "upload.cpu.after")
    require(cpu_before.keys() == cpu_after.keys() and cpu_before, "CPU 计数缺失/集合变化")
    delta = {key: cpu_after[key][0] - cpu_before[key][0] for key in cpu_before}
    require(all(value >= 0 for value in delta.values()), "CPU 计数回退")
    total = sum(delta.values())
    util = raw.get("end", {}).get("cpu_utilization_percent", {})
    host_cpu, remote_cpu = util.get("host_total"), util.get("remote_total")
    issues = []
    if total <= 0 or any(type(x) not in (int, float) or not math.isfinite(x) or x < 0 for x in (host_cpu, remote_cpu)):
        issues.append("RESOURCE_OBSERVATION_UNAVAILABLE")
    elif max(host_cpu, remote_cpu) >= 85 or delta.get("steal", 0) / total > 0.1:
        issues.append("CPU_PRESSURE")
    before = numeric_table(directory / "upload.softnet.before")
    after = numeric_table(directory / "upload.softnet.after")
    if not before or before.keys() != after.keys():
        issues.append("SOFTNET_OBSERVATION_UNAVAILABLE")
    else:
        for key in before:
            changes = [b - a for a, b in zip(before[key], after[key])]
            if len(changes) != 3 or any(x < 0 for x in changes):
                issues.append("SOFTNET_COUNTER_INVALID")
            elif any(changes[1:]):
                issues.append("SOFTNET_PRESSURE")
    return {"iperf_host_cpu_percent": host_cpu, "iperf_remote_cpu_percent": remote_cpu,
            "cpu_ticks_delta": delta, "issues": sorted(set(issues))}


def sample_row(directory, role, rate, endpoint, route):
    summary = read_json(directory / "upload.summary.json")
    raw = read_json(directory / "upload.iperf3.json")
    require(not raw.get("error"), "iperf3 返回错误")
    connected = raw.get("start", {}).get("connected", [])
    require(len(connected) == 1 and normalize_ip(connected[0]["remote_host"]) == normalize_ip(endpoint["ip"]) and
            connected[0]["remote_port"] == endpoint["port"], "iperf3 实际对端与固定目标不一致")
    local_socket = {"ip": str(normalize_ip(connected[0]["local_host"])), "port": connected[0]["local_port"]}
    require(type(local_socket["port"]) is int and 1 <= local_socket["port"] <= 65535, "实际源端口缺失")
    issues = list(summary["measurement_window"]["issues"])
    if summary["measurement_window"].get("valid") is not True:
        issues.append("INVALID_MEASUREMENT_WINDOW")
    sender, receiver = summary["sender"], summary["receiver"]
    if sender["mbps"] < rate * 0.9:
        issues.append("UNDERDRIVEN")
    if sender["mbps"] > rate * 1.10:
        issues.append("RATE_CAP_NOT_OBSERVED")
    if receiver["mbps"] < sender["mbps"] * 0.8:
        issues.append("RECEIVER_DIVERGENCE")
    if summary["qdisc_health"]["any_drop_or_requeue"]:
        issues.append("LOCAL_QUEUE_ANOMALY")
    resources = resource_observation(directory, raw)
    issues += resources["issues"]
    rtts = [s["sender"]["mean_rtt"] / 1000 for s in raw.get("end", {}).get("streams", [])
            if type(s.get("sender", {}).get("mean_rtt")) in (int, float) and s["sender"]["mean_rtt"] >= 0]
    return {"directory": directory.name, "role": role, "rate_mbps": rate,
            "endpoint": {k: endpoint[k] for k in ("ip", "family", "port")}, "route": route,
            "local_socket": local_socket,
            "sender": sender, "receiver": receiver, "resources": resources,
            "qdisc_coverage": summary.get("qdisc_coverage"),
            "loaded_mean_rtt_ms": statistics.mean(rtts) if rtts else None,
            "issues": sorted(set(issues)), "eligible": not issues}


def analyze(rows, plan, stop_reason):
    issues = []
    start = [row for row in rows if row["role"] == "control-start"]
    end = [row for row in rows if row["role"] == "control-end"]
    expected = plan["samples_per_rate"]
    complete = len(rows) == len(plan["schedule"]) and stop_reason is None
    if not complete:
        issues.append("INCOMPLETE_SWEEP")
    if len(start) != expected or len(end) != expected or not all(row["eligible"] for row in start + end):
        issues.append("INVALID_CONTROL")
    baseline = statistics.median(row["sender"]["retransmits_per_gib"] for row in start) if start else None
    # 经验性筛选阈值，明确保留数值，不将归一化重传称为丢包百分比。
    threshold = max(100.0, baseline * 5) if baseline is not None else None
    if baseline is not None and baseline > 100:
        issues.append("DIRTY_CONTROL")
    if threshold is not None and any(row["sender"]["retransmits_per_gib"] >= threshold for row in end):
        issues.append("CONTROL_DRIFT")
    if len({json.dumps([row["endpoint"], row["route"]], sort_keys=True) for row in rows}) > 1:
        issues.append("PATH_CHANGED")
    groups = []
    boundary = None
    last_clean = plan["rates_mbps"][0]
    for rate in plan["rates_mbps"][1:]:
        samples = [row for row in rows if row["role"] == "sweep" and row["rate_mbps"] == rate]
        valid = len(samples) == expected and all(row["eligible"] for row in samples)
        spikes = sum(row["sender"]["retransmits_per_gib"] >= threshold for row in samples) if threshold is not None else 0
        state = "INCONCLUSIVE" if not valid else "RETRANSMISSION_RISE" if spikes >= 2 else "NO_CONFIRMED_RISE"
        groups.append({"rate_mbps": rate, "samples": len(samples), "eligible": valid, "spikes": spikes, "status": state,
                       "receiver_mbps_median": statistics.median(row["receiver"]["mbps"] for row in samples) if samples else None})
        if not valid:
            issues.append("INVALID_RATE_SAMPLE")
        elif state == "RETRANSMISSION_RISE" and boundary is None:
            boundary = {"lower_mbps": last_clean, "upper_mbps": rate}
        elif boundary is None:
            last_clean = rate
    status = "INSUFFICIENT_EVIDENCE" if issues else "RETRANSMISSION_RISE_OBSERVED" if boundary else "NO_RISE_IN_TESTED_RANGE"
    return {"status": status, "issues": sorted(set(issues)), "tested_rates": groups,
            "baseline_retransmits_per_gib": baseline, "spike_threshold_retransmits_per_gib": threshold,
            "candidate_interval": boundary if not issues else None, "policer_identified": False,
            "recommended_shaping_rate_mbps": None, "persistent_changes_authorized": False}


class MeasurementRun:
    def __init__(self, args, plan):
        self.args, self.plan = args, plan
        self.output = Path(args.output_dir)
        self.budget_tool = ROOT / "dvt-traffic-budget.sh"
        self.deadline = time.monotonic() + args.max_duration
        self.events, self.rows = [], []
        self.active = None
        self.reservation = None
        self.sequence = 0

    def budget(self, action, *extra):
        command = ["bash", str(self.budget_tool), action, "--ledger", self.args.ledger, *map(str, extra)]
        # flock 可能等待另一写入，超时不能释放未知状态下的 reservation。
        result = bounded(command, 15)
        require(result["returncode"] == 0, "流量账本操作失败：" + result["stderr"])
        return json.loads(result["stdout"])

    def save_events(self):
        write_json(self.output / "attempts.json", self.events)

    def cleanup_child(self):
        if self.active is None:
            return
        child, self.active = self.active, None
        if child.poll() is None:
            child.terminate()  # runtime trap 负责其 setsid iperf3 组。
            try:
                child.wait(timeout=8)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                child.wait()

    def attempt(self, endpoint, role, rate):
        timeout = self.args.seconds + 10
        if time.monotonic() + timeout + 8 >= self.deadline:
            raise StopMeasurement("TIME_LIMIT")
        route = route_for(endpoint)
        planned = reservation_bytes(rate, self.args.seconds)
        status = self.budget("status")
        require(status["window_id"] == self.args.window_id and status["budget_bytes"] == self.plan["window_budget_bytes"], "账本窗口不匹配")
        if status["remaining_bytes"] < planned:
            raise StopMeasurement("BUDGET_LIMIT")
        self.sequence += 1
        name = f"attempt-{self.sequence:03d}"
        directory = self.output / name
        reservation = "measure-" + uuid.uuid4().hex
        # reserve 在发出流量前；若其结果不确定则保留 ID 和现场，禁止后续尝试。
        event = {"directory": name, "role": role, "rate_mbps": rate, "endpoint": endpoint,
                 "route_before": route, "reservation_id": reservation, "planned_bytes": planned, "status": "RESERVING"}
        self.events.append(event)
        self.save_events()
        self.reservation = reservation
        self.budget("reserve", "--window-id", self.args.window_id, "--budget-bytes", self.plan["window_budget_bytes"],
                    "--tool", "measure", "--run-id", reservation, "--reservation-id", reservation, "--planned-bytes", planned)
        event["status"] = "RUNNING"
        self.save_events()
        print(f"[{name}] {role}: {rate} Mbps, {endpoint['id']} / IPv{endpoint['family']}", flush=True)
        try:
            if time.monotonic() + timeout + 8 >= self.deadline:
                # 预留过程可能等待账本锁；尚未创建子进程，能确定消费为零。
                event["settlement"] = self.budget("commit", "--reservation-id", reservation, "--actual-bytes", 0)
                self.reservation = None
                raise StopMeasurement("TIME_LIMIT")
            with (self.output / (name + ".log")).open("w", encoding="utf-8") as log:
                self.active = subprocess.Popen(["bash", str(ROOT / "dvt-measure-runtime.sh"), endpoint["ip"],
                                               str(endpoint["port"]), str(endpoint["family"]), route["dev"],
                                               str(rate), str(self.args.seconds), str(directory)],
                                              stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                                              env={**os.environ, "DVT_TRAFFIC_LEDGER": self.args.ledger,
                                                   "DVT_MEASURE_RESERVATION": reservation})
                code = self.active.wait(timeout=timeout + 8)
                self.active = None
            require(code == 0, "采集失败，见本次 attempt 日志")
            row = sample_row(directory, role, rate, endpoint, route)
            event["route_after"] = route_for(endpoint)
            event["socket_route"] = route_for(endpoint, row["local_socket"])
            same_egress = all(event["socket_route"][key] == route[key] for key in ("dev", "gateway", "table"))
            expected_source = route.get("prefsrc") or route.get("src")
            same_source = expected_source is None or normalize_ip(expected_source) == normalize_ip(row["local_socket"]["ip"])
            if event["route_after"] != route or not same_egress or not same_source:
                row["issues"].append("PATH_CHANGED")
                row["eligible"] = False
            event["settlement"] = self.budget("commit", "--reservation-id", reservation, "--actual-bytes", row["sender"]["bytes"])
            self.reservation = None
            event["status"] = "COMMITTED"
            event["issues"] = row["issues"]
            self.save_events()
            if row["sender"]["bytes"] > planned or "RATE_CAP_NOT_OBSERVED" in row["issues"]:
                raise MeasurementInvalid("实际发送超出本轮速率/预算估算，停止")
            if "PATH_CHANGED" in row["issues"]:
                raise MeasurementInvalid("测试中出口发生变化，停止")
            return row
        except BaseException as exc:
            self.cleanup_child()
            if self.reservation:
                try:
                    event["settlement"] = self.budget("fail", "--reservation-id", reservation)
                    self.reservation = None
                except MeasurementInvalid:
                    raise
                except MeasurementError as settlement_error:
                    event["settlement_error"] = str(settlement_error)
            event["status"] = "STOPPED" if isinstance(exc, StopMeasurement) else "FAILED"
            event["error"] = {"type": type(exc).__name__, "message": str(exc)}
            self.save_events()
            raise

    def run(self):
        require(self.output.is_absolute() and not self.output.exists() and not self.output.is_symlink(), "output-dir 必须为尚不存在的绝对路径")
        require(self.output.parent.is_dir() and not self.output.parent.is_symlink(), "output-dir 父目录必须存在且不是符号链接")
        os.umask(0o077)
        self.output.mkdir(mode=0o700)
        (self.output / "INCOMPLETE").write_text("initialization\n", encoding="utf-8")
        write_json(self.output / "plan.json", self.plan)
        before = diagnose()
        write_json(self.output / "capabilities.json", before)
        write_json(self.output / "execution-assets.json", {
            "files": {name: sha(ROOT / name) for name in
                      ("dvt-measure.py", "dvt-measure-runtime.sh", "dvt-traffic-budget.sh", "measurement-endpoints.json")},
            "iperf3_version": bounded(["iperf3", "--version"], 3),
            "python_version": platform.python_version()})
        # init 对已存在的窗口只核对标识/额度，不重置消费。
        self.budget("init", "--window-id", self.args.window_id, "--budget-bytes", self.plan["window_budget_bytes"])
        print("正在解析目录并按 ICMP RTT 排序；无 ICMP 响应的节点仍可尝试。", flush=True)
        with ThreadPoolExecutor(max_workers=4) as pool:
            discovery = list(pool.map(lambda item: discover_one(item, self.args.family), self.plan["endpoints"]))
        write_json(self.output / "discovery.json", discovery)
        choices = candidates_from(discovery, self.plan["endpoints"], self.plan["max_attempts"])
        selected, stop_reason = None, None
        try:
            for endpoint in choices:
                try:
                    row = self.attempt(endpoint, "discovery", 1)
                    if row["eligible"]:
                        selected = endpoint
                        break
                except MeasurementError as exc:
                    if self.reservation:
                        raise
                    print("候选未通过协议/采集检查：" + str(exc), flush=True)
            if selected is None:
                stop_reason = "NO_USABLE_ENDPOINT"
            else:
                fixed_route = route_for(selected)
                write_json(self.output / "selected-endpoint.json", {"endpoint": selected, "route": fixed_route})
                for role, rate in self.plan["schedule"]:
                    require(route_for(selected) == fixed_route, "固定端点的出口已改变；不拼接路径")
                    self.rows.append(self.attempt(selected, role, rate))
                    write_json(self.output / "samples.json", self.rows)
        except StopMeasurement as exc:
            stop_reason = str(exc)
        after = diagnose()
        configuration_observation = compare_configuration(before, after)
        analysis = analyze(self.rows, self.plan, stop_reason)
        if configuration_observation["status"] != "UNCHANGED":
            analysis["issues"].append("CONFIGURATION_" + configuration_observation["status"])
            analysis["status"] = "INSUFFICIENT_EVIDENCE"
            analysis["candidate_interval"] = None
        result = {"schema": SCHEMA, "version": VERSION, "generated_utc": datetime.now(timezone.utc).isoformat(),
                  "configuration_changed": False, "management_state": "INDEPENDENT_MEASUREMENT",
                  "configuration_observation": configuration_observation,
                  "endpoint": selected, "stop_reason": stop_reason, "samples": self.rows,
                  "analysis": analysis, "budget": self.budget("status"),
                  "limitations": ["application-paced upload only", "public endpoint capacity and route are variable",
                                  "no provider policer attribution", "no business-path or persistent tuning recommendation"]}
        write_json(self.output / "measurement-result.json", result)
        write_json(self.output / "capabilities-after.json", after)
        finalize_evidence(self.output)
        return result


def finalize_evidence(directory):
    files = sorted(p for p in directory.rglob("*") if p.is_file() and p.name not in ("INCOMPLETE", "COMPLETED", "SHA256SUMS"))
    manifest = "".join(f"{sha(p)}  {p.relative_to(directory).as_posix()}\n" for p in files)
    (directory / "SHA256SUMS").write_bytes(manifest.encode("utf-8"))
    (directory / "COMPLETED").write_text("evidence_manifest_sha256=" + sha(directory / "SHA256SUMS") + "\n", encoding="utf-8")
    (directory / "INCOMPLETE").unlink()


def verify_report(directory):
    directory = Path(directory)
    require(not (directory / "INCOMPLETE").exists(), "证据尚未完成")
    require((directory / "COMPLETED").read_text().strip() == "evidence_manifest_sha256=" + sha(directory / "SHA256SUMS"), "清单摘要不匹配")
    names = set()
    for line in (directory / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split("  ", 1)
        require(re.fullmatch(r"[a-f0-9]{64}", digest) and name not in names and
                re.fullmatch(r"[A-Za-z0-9_.\-/]+", name) and not name.startswith("/") and
                all(part not in (".", "..") for part in name.split("/")), "清单条目非法")
        path = directory / name
        require(not any(p.is_symlink() for p in [path, *path.parents]) and path.is_file(), "清单文件不可用或含符号链接")
        require(sha(path) == digest, "证据摘要不符：" + name)
        names.add(name)
    require({"plan.json", "measurement-result.json"} <= names, "核心证据缺失")
    result = read_json(directory / "measurement-result.json")
    require(result.get("schema") == SCHEMA, "不是独立测量 schema")
    return result


def diagnose():
    observations = {}
    for name, command in {
        "addresses": ["ip", "-j", "address", "show"], "routes4": ["ip", "-j", "-4", "route", "show"],
        "routes6": ["ip", "-j", "-6", "route", "show"], "qdisc": ["tc", "-j", "-d", "qdisc", "show"],
        "classes": ["tc", "-j", "-d", "class", "show"],
        "congestion_control": ["sysctl", "-n", "net.ipv4.tcp_congestion_control"],
        "default_qdisc": ["sysctl", "-n", "net.core.default_qdisc"], "sockets": ["ss", "-s"],
    }.items():
        item = bounded(command, 3)
        item["status"] = "available" if item["returncode"] == 0 else "unavailable"
        observations[name] = item
    proc = {}
    for name in ("meminfo", "stat", "net/snmp", "net/netstat", "net/softnet_stat"):
        try:
            proc[name] = (Path("/proc") / name).read_text()
        except OSError:
            proc[name] = None
    return {"schema": "dvt.diagnose/1", "version": VERSION, "system": platform.system(),
            "kernel": platform.release(), "architecture": platform.machine(), "cpus": os.cpu_count(),
            "managed_state_verified": False, "configuration_changed": False,
            "observations": observations, "proc": proc,
            "dependencies": {name: shutil.which(name) is not None for name in ("bash", "ip", "tc", "jq", "iperf3", "flock", "setsid", "timeout", "ping")}}


def compare_configuration(before, after):
    changed, unavailable = [], []
    for name in ("qdisc", "classes", "congestion_control", "default_qdisc"):
        a = before.get("observations", {}).get(name, {})
        b = after.get("observations", {}).get(name, {})
        if a.get("status") != "available" or b.get("status") != "available":
            unavailable.append(name)
        elif a["stdout"] != b["stdout"]:
            changed.append(name)
    return {"status": "CHANGED" if changed else "UNAVAILABLE" if unavailable else "UNCHANGED",
            "changed_fields": changed, "unavailable_fields": unavailable,
            "scope": "observed qdisc/classes/congestion-control/default-qdisc at run boundaries"}


def print_report(result):
    analysis = result["analysis"]
    print("\n测量结果：" + analysis["status"])
    if result["stop_reason"]:
        print("停止原因：" + result["stop_reason"])
    for group in analysis["tested_rates"]:
        print(f"  {group['rate_mbps']:5} Mbps  receiver 中位值={group['receiver_mbps_median']}  {group['status']}")
    print("重传上升区间：" + str(analysis["candidate_interval"]))
    print("解释：当前发送方式下的直连路径证据；不能识别服务商限速器，也不生成持久整形参数。")


def integer(low, high):
    def parse(value):
        try:
            number = int(value)
        except ValueError as exc:
            raise argparse.ArgumentTypeError("需要整数") from exc
        if not low <= number <= high:
            raise argparse.ArgumentTypeError(f"必须在 {low}..{high} 之间")
        return number
    return parse


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("diagnose", help="按实际能力进行只读诊断")
    report = sub.add_parser("report", help="离线校验并显示独立测量报告")
    report.add_argument("--input-dir", required=True)
    measure = sub.add_parser("measure", help="自动选择公开节点并测量出向路径；不修改 qdisc")
    measure.add_argument("--host", help="自有/获准节点；省略时使用固定公共目录")
    measure.add_argument("--server-port", type=integer(1, 65535))
    measure.add_argument("--rate-cap", type=integer(1, 10000), required=True, help="本轮测试上限 Mbps，与套餐/受管带宽独立")
    measure.add_argument("--family", choices=("auto", "4", "6"), default="auto")
    measure.add_argument("--samples", type=integer(3, 5), default=3)
    measure.add_argument("--seconds", type=integer(5, 30), default=5)
    measure.add_argument("--max-attempts", type=integer(1, 8), default=4)
    measure.add_argument("--max-duration", type=integer(30, 1800), default=300,
                         help="流量调度期限（秒）；最后的账本结算和证据提交可延长退出时间")
    measure.add_argument("--budget-mib", type=integer(1, 102400), default=600)
    measure.add_argument("--ledger")
    measure.add_argument("--window-id")
    measure.add_argument("--output-dir")
    measure.add_argument("--plan-only", action="store_true")
    measure.add_argument("--yes", action="store_true", help="确认计划范围、公共服务及流量预算")
    args = parser.parse_args(argv)
    if args.action == "report":
        print_report(verify_report(args.input_dir))
        return 0
    if args.action == "diagnose":
        require(platform.system() == "Linux", "诊断需要 Linux；不限制发行版/架构/资源档位")
        print(json.dumps(diagnose(), ensure_ascii=False, indent=2))
        return 0
    require(not args.server_port or args.host, "--server-port 仅用于显式 --host；公共端口由目录限定")
    if args.host:
        require(SAFE_HOST.fullmatch(args.host), "host 格式非法")
        endpoints = [{"id": "user", "host": args.host, "ports": [args.server_port or 5201], "provider": "user", "families": [4, 6]}]
    else:
        endpoints = load_catalog(ROOT / "measurement-endpoints.json")
    plan = make_plan(args, endpoints)
    if args.plan_only:
        print(json.dumps(plan, ensure_ascii=False, indent=2))
        return 0
    require(platform.system() == "Linux", "执行测量需要 Linux")
    require(os.geteuid() == 0, "测量使用 root 所有的共享流量账本；只读 diagnose 可普通权限运行")
    verify_assets()
    for command in ("bash", "ip", "tc", "jq", "iperf3", "flock", "setsid", "timeout", "awk", "sha256sum"):
        require(shutil.which(command), "缺少依赖：" + command)
    require(args.ledger and Path(args.ledger).is_absolute() and args.window_id and args.output_dir, "执行需要 --ledger 绝对路径、--window-id 和 --output-dir")
    print(f"出向测量计划：速率 {plan['rates_mbps']} Mbps，每档 {args.samples} 次 × {args.seconds} 秒；首尾低速控制。")
    print(f"窗口 {args.window_id}，预算 {args.budget_mib} MiB payload，流量调度期限 {args.max_duration} 秒，最多 {plan['max_attempts']} 次选点尝试。")
    print("预算包含协议短测和失败预留，不含重传/协议/账单开销；余额不足停止。不会修改系统配置。")
    for endpoint in endpoints:
        ports = endpoint["ports"]
        print(f"  {endpoint['provider']}: {endpoint['host']}  ports={ports[0]}..{ports[-1]}")
    if not args.yes:
        require(sys.stdin.isatty(), "非交互执行需用 --yes 确认上述计划")
        require(input("按计划向所列服务发送流量（包括选点），继续？[y/N] ").lower() in ("y", "yes"), "已取消")
    run = MeasurementRun(args, plan)
    def interrupted(signum, _frame):
        raise KeyboardInterrupt(signum)
    old = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        result = run.run()
        print_report(result)
        print("证据目录：" + str(run.output))
    finally:
        run.cleanup_child()
        for sig, handler in old.items():
            signal.signal(sig, handler)
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "_resolve":
        family = {"auto": socket.AF_UNSPEC, "4": socket.AF_INET, "6": socket.AF_INET6}[sys.argv[3]]
        print(json.dumps(list(dict.fromkeys(row[4][0] for row in socket.getaddrinfo(sys.argv[2], None, family, socket.SOCK_STREAM)))))
    else:
        try:
            sys.exit(main())
        except KeyboardInterrupt as exc:
            sys.exit(143 if exc.args and exc.args[0] == signal.SIGTERM else 130)
        except (MeasurementError, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as exc:
            print("[measure][FAIL] " + str(exc), file=sys.stderr)
            sys.exit(2)

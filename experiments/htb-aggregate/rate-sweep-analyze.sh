#!/usr/bin/env bash
# Build descriptive statistics from a completed HTB reference/sweep evidence tree.
# The output is a review aid, never an automatic production recommendation.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

ANALYZER_VERSION='0.4.0'

die() { printf '[rate-sweep-analyze][FAIL] %s\n' "$*" >&2; exit 1; }

cpu_delta_json() {
  local before="$1" after="$2"
  awk -F '\t' '
    function uint(value) {return value ~ /^[0-9]+$/}
    BEGIN {
      expected["user"]=expected["nice"]=expected["system"]=expected["idle"]=1
      expected["iowait"]=expected["irq"]=expected["softirq"]=expected["steal"]=1
    }
    FILENAME == ARGV[1] {
      if (!($1 in expected) || !uint($2) || ($1 in old)) exit 40
      old[$1]=$2; before_count++; next
    }
    {
      if (!($1 in expected) || !uint($2) || !($1 in old) || ($1 in seen_after)) exit 41
      delta=$2-old[$1]
      if (delta < 0) exit 42
      seen_after[$1]=1
      value[$1]=delta
      total+=delta
      after_count++
    }
    END {
      if (before_count != 8 || before_count != after_count || total <= 0) exit 43
      for (key in expected) {
        if (!(key in old) || !(key in seen_after)) exit 44
      }
      printf "{\"total_ticks\":%d,\"idle_percent\":%.6f,\"softirq_percent\":%.6f,\"steal_percent\":%.6f}\n", \
        total, value["idle"]*100/total, value["softirq"]*100/total, value["steal"]*100/total
    }
  ' "$before" "$after"
}

softnet_delta_json() {
  local before="$1" after="$2"
  awk -F '\t' '
    function uint(value) {return value ~ /^[0-9]+$/}
    FILENAME == ARGV[1] {
      if (!uint($1) || !uint($2) || !uint($3) || !uint($4) || ($1 in processed)) exit 45
      processed[$1]=$2; dropped[$1]=$3; squeezed[$1]=$4; before_count++; next
    }
    {
      if (!uint($1) || !uint($2) || !uint($3) || !uint($4) ||
          !($1 in processed) || ($1 in seen_after)) exit 46
      processed_delta=$2-processed[$1]
      dropped_delta=$3-dropped[$1]
      squeezed_delta=$4-squeezed[$1]
      if (processed_delta < 0 || dropped_delta < 0 || squeezed_delta < 0) exit 47
      seen_after[$1]=1
      processed_total+=processed_delta
      dropped_total+=dropped_delta
      squeezed_total+=squeezed_delta
      after_count++
    }
    END {
      if (before_count == 0 || before_count != after_count) exit 48
      for (cpu in processed) if (!(cpu in seen_after)) exit 49
      printf "{\"processed_delta\":%d,\"dropped_delta\":%d,\"time_squeeze_delta\":%d}\n", \
        processed_total, dropped_total, squeezed_total
    }
  ' "$before" "$after"
}

main() {
  local evidence_dir="${1:-}" plan session_meta samples_file stage_json sequence label stage_dir benchmark_dir
  local stage_result_sha actual_result_sha actual_manifest_sha cpu_json softnet_json
  [ "$#" -eq 1 ] || die '用法：rate-sweep-analyze.sh /absolute/completed-or-in-progress-sweep-dir'
  command -v jq >/dev/null 2>&1 || die '缺少命令：jq'
  command -v sha256sum >/dev/null 2>&1 || die '缺少命令：sha256sum'
  [[ "$evidence_dir" = /* ]] || die '证据目录必须是绝对路径。'
  [ -d "$evidence_dir" ] || die "证据目录不存在：${evidence_dir}"
  plan="${evidence_dir}/plan.json"
  session_meta="${evidence_dir}/session-meta.json"
  [ -s "$plan" ] || die '缺少 plan.json。'
  [ -s "$session_meta" ] || die '缺少 session-meta.json。'
  jq -e '
    .schema_version == 2 and
    (.runner_version | type == "string") and
    (.tuning_script.sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
    .managed_binding.state == "VERIFIED" and
    .managed_binding.script_version == "0.1.0-rc.17" and
    ((.managed_binding.profile_id == "debian13-1c1g") or
     (.managed_binding.profile_id == "debian13-1c2g")) and
    .managed_binding.port_speed_mbps == 200 and
    (.managed_binding.state_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
    .persistent_shaping_authorized == false
  ' "$session_meta" >/dev/null || die 'session-meta.json 的 managed/profile 绑定无效。'
  jq -e '
    . as $plan |
    .schema_version == 3 and
    ((.mode == "reference-screen") or (.mode == "candidate-sweep")) and
    .scope.provider_port_mbit == 200 and
    .scope.direction == "upload" and .scope.persistent_shaping_authorized == false and
    .reference_rate_mbit == 200 and
    (.rates_mbit | type == "array") and
    ((.rates_mbit | length) == (.rates_mbit | unique | length)) and
    (if .mode == "reference-screen" then (.rates_mbit | length) == 0
     else (.rates_mbit | length) >= 3 and (.rates_mbit | length) <= 8 and
          all(.rates_mbit[]; type == "number" and floor == . and . >= 100 and . <= 199)
     end) and
    (.controls.samples_per_state | type == "number" and floor == . and . >= 2 and . <= 5) and
    (.controls.minimum_rate_exposure_ratio | type == "number" and . >= 0.9 and . <= 1) and
    (.controls.minimum_cpu_idle_percent | type == "number" and . >= 0 and . <= 100) and
    (.controls.maximum_cpu_steal_percent | type == "number" and . >= 0 and . <= 100) and
    .controls.require_zero_softnet_drops == true and
    .controls.require_zero_softnet_time_squeeze == true and
    .controls.require_zero_link_drops_errors == true and
    (if .mode == "reference-screen" then
       .reference_gate.external_reference_required == false and
       .reference_gate.review_acknowledged == false and
       .reference_gate.evidence_manifest_sha256 == null and
       .reference_gate.analysis_sha256 == null and
       .reference_gate.completed_marker_sha256 == null
     else
       .reference_gate.external_reference_required == true and
       .reference_gate.review_acknowledged == true and
       (.reference_gate.evidence_manifest_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
       (.reference_gate.analysis_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
       (.reference_gate.completed_marker_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
     end) and
    .reference_gate.reference_path_recorded == false and
    .reference_gate.persistence_authorized == false and
    (.stages | type == "array" and length >= 2 and length <= 50) and
    (if .mode == "reference-screen" then
       (.stages | length) == .controls.samples_per_state
     else
       (.stages | length) == (.controls.samples_per_state * ((.rates_mbit | length) + 2))
     end) and
    ([.stages[].sequence] == [range(1; (.stages|length) + 1)]) and
    (([.stages[].label] | length) == ([.stages[].label] | unique | length)) and
    all(.stages[];
      .rate_cap_mbit == .rate_mbit and
      .traffic_cap_enforced_by == "htb-class-rate-and-ceil" and
      ((.condition == "reference-htb" and .rate_mbit == 200 and
        (if $plan.mode == "reference-screen" then .phase == "reference-screen"
         else (.phase == "reference-start" or .phase == "reference-end") end)) or
       (.condition == "candidate-htb" and .phase == "candidate-sweep" and
        (.rate_mbit as $stage_rate | ($plan.rates_mbit | index($stage_rate)) != null)))) and
    (if .mode == "reference-screen" then
       all(.stages[]; .condition == "reference-htb")
     else
       ([.stages[] | select(.phase == "reference-start")] | length) == .controls.samples_per_state and
       ([.stages[] | select(.phase == "reference-end")] | length) == .controls.samples_per_state and
       ([.rates_mbit[] as $rate |
         (([.stages[] | select(.condition == "candidate-htb" and .rate_mbit == $rate)] | length) ==
          .controls.samples_per_state)] | all)
     end) and
    .traffic_budget.enforced_by == "htb-class-rate-and-ceil" and
    .traffic_budget.stage_count == (.stages | length) and
    .traffic_budget.payload_upper_bound_bytes ==
      (([.stages[].rate_mbit] | add) * 125000 *
       (.benchmark.seconds + .benchmark.omit_seconds))
  ' "$plan" >/dev/null || die 'plan.json 不符合 HTB reference/candidate schema。'

  samples_file="$(mktemp)"
  trap 'rm -f -- "$samples_file"' EXIT INT TERM
  while IFS= read -r stage_json; do
    sequence="$(jq -r '.sequence' <<<"$stage_json")"
    label="$(jq -r '.label' <<<"$stage_json")"
    stage_dir="${evidence_dir}/stages/$(printf '%02d-%s' "$sequence" "$label")"
    benchmark_dir="${stage_dir}/benchmark"
    [ -s "${stage_dir}/stage-result.json" ] || die "缺少阶段结果：${label}"
    jq -e --argjson expected "$stage_json" --slurpfile session "$session_meta" '
      .schema_version == 3 and .status == "PASS" and
      .plan_stage == $expected and .qdisc_restored_to_root_fq == true and
      .persistent_shaping_created == false and
      .traffic_cap_enforced_by_htb == true and
      .qdisc_rate_mbit == $expected.rate_mbit and
      .benchmark_binding_valid == true and
      .managed_binding.profile_id == $session[0].managed_binding.profile_id and
      .managed_binding.script_version == $session[0].managed_binding.script_version and
      .managed_binding.state == "VERIFIED" and
      .managed_binding.port_speed_mbps == 200 and
      .managed_binding.state_sha256 == $session[0].managed_binding.state_sha256 and
      .managed_binding.tuning_script_sha256 == $session[0].tuning_script.sha256 and
      (.benchmark_result_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    ' "${stage_dir}/stage-result.json" >/dev/null || die "阶段结果内容无效：${label}"
    [ -f "${benchmark_dir}/COMPLETED" ] && [ ! -f "${benchmark_dir}/INCOMPLETE" ] ||
      die "benchmark 未完成：${label}"
    [ -s "${benchmark_dir}/upload.summary.json" ] || die "缺少 upload.summary.json：${label}"
    [ -s "${benchmark_dir}/benchmark-result.json" ] || die "缺少 benchmark-result.json：${label}"
    [ -s "${benchmark_dir}/benchmark-meta.json" ] || die "缺少 benchmark-meta.json：${label}"
    for required_counter_file in upload.cpu.before upload.cpu.after upload.softnet.before upload.softnet.after; do
      [ -s "${benchmark_dir}/${required_counter_file}" ] ||
        die "缺少结构化资源计数器 ${required_counter_file}：${label}"
    done
    (
      cd "$benchmark_dir"
      sha256sum -c SHA256SUMS >/dev/null
    ) || die "benchmark manifest 校验失败：${label}"
    jq -e '.schema_version == 1 and .status == "PASS" and .exit_code == 0 and
      .phases.upload != null and .phases.download == null' \
      "${benchmark_dir}/benchmark-result.json" >/dev/null || die "benchmark-result 无效：${label}"
    jq -e --slurpfile session "$session_meta" '
      .schema_version == 1 and .profile == $session[0].managed_binding.profile_id and
      .script_version == $session[0].managed_binding.script_version and
      .script_sha256 == $session[0].tuning_script.sha256 and
      .state == "VERIFIED" and .state_network.port_speed_mbps == 200
    ' "${benchmark_dir}/benchmark-meta.json" >/dev/null ||
      die "benchmark-meta profile/state 绑定无效：${label}"
    stage_result_sha="$(jq -r '.benchmark_result_sha256 // empty' "${stage_dir}/stage-result.json")"
    actual_result_sha="$(sha256sum "${benchmark_dir}/benchmark-result.json" | awk '{print $1}')"
    actual_manifest_sha="$(sha256sum "${benchmark_dir}/SHA256SUMS" | awk '{print $1}')"
    [ "$stage_result_sha" = "$actual_result_sha" ] || die "阶段结果与 benchmark hash 不匹配：${label}"
    grep -Fxq "result_sha256=${actual_result_sha}" "${benchmark_dir}/COMPLETED" ||
      die "COMPLETED 未绑定 benchmark-result：${label}"
    grep -Fxq "evidence_manifest_sha256=${actual_manifest_sha}" \
      "${benchmark_dir}/COMPLETED" || die "COMPLETED 未绑定 benchmark manifest：${label}"
    cpu_json="$(cpu_delta_json "${benchmark_dir}/upload.cpu.before" "${benchmark_dir}/upload.cpu.after")" ||
      die "无法解析 CPU 增量：${label}"
    softnet_json="$(softnet_delta_json "${benchmark_dir}/upload.softnet.before" "${benchmark_dir}/upload.softnet.after")" ||
      die "无法解析 softnet 增量：${label}"
    jq -n --argjson stage "$stage_json" \
      --argjson cpu "$cpu_json" --argjson softnet "$softnet_json" \
      --slurpfile plan "$plan" --slurpfile summary "${benchmark_dir}/upload.summary.json" '
        def nonnegative_number($value):
          ($value | type) == "number" and $value >= 0;
        def upload_summary_contract_valid($s):
          ($s | type) == "object" and $s.schema_version == 3 and
          $s.direction == "upload" and $s.reverse == false and
          ($s.measurement_window.valid | type) == "boolean" and
          ($s.measurement_window.issues | type) == "array" and
          nonnegative_number($s.sender.seconds) and $s.sender.seconds > 0 and
          nonnegative_number($s.sender.mbps) and
          nonnegative_number($s.sender.retransmits) and
          nonnegative_number($s.sender.retransmits_per_gib) and
          nonnegative_number($s.receiver.seconds) and $s.receiver.seconds > 0 and
          nonnegative_number($s.receiver.mbps) and
          ($s.host.link_delta | type) == "object" and
          ($s.qdisc_coverage.topology == "htb-fq") and
          ($s.qdisc_coverage.root_is_htb == true) and
          ($s.qdisc_coverage.has_leaf == true) and
          ($s.qdisc_coverage.htb_fq_leaf_complete == true) and
          nonnegative_number($s.qdisc_root_totals.overlimits_delta) and
          nonnegative_number($s.qdisc_root_totals.dropped_delta) and
          nonnegative_number($s.qdisc_root_totals.requeues_delta) and
          nonnegative_number($s.qdisc_leaf_totals.dropped_delta) and
          nonnegative_number($s.qdisc_leaf_totals.requeues_delta) and
          ($s.qdisc_health.any_drop_or_requeue | type) == "boolean" and
          (($s.qdisc_health.status == "NO_LOCAL_QUEUE_DROP_OR_REQUEUE") or
           ($s.qdisc_health.status == "LOCAL_QUEUE_ANOMALY")) and
          ($s.qdisc_health.root.dropped_delta == $s.qdisc_root_totals.dropped_delta) and
          ($s.qdisc_health.root.requeues_delta == $s.qdisc_root_totals.requeues_delta) and
          ($s.qdisc_health.leaf.dropped_delta == $s.qdisc_leaf_totals.dropped_delta) and
          ($s.qdisc_health.leaf.requeues_delta == $s.qdisc_leaf_totals.requeues_delta) and
          ($s.qdisc_health.any_drop_or_requeue ==
            (($s.qdisc_root_totals.dropped_delta > 0) or
             ($s.qdisc_root_totals.requeues_delta > 0) or
             ($s.qdisc_leaf_totals.dropped_delta > 0) or
             ($s.qdisc_leaf_totals.requeues_delta > 0))) and
          ($s.qdisc_health.status ==
            (if $s.qdisc_health.any_drop_or_requeue then
               "LOCAL_QUEUE_ANOMALY"
             else "NO_LOCAL_QUEUE_DROP_OR_REQUEUE" end));
        ($summary[0]) as $s |
        ($plan[0]) as $p |
        if (upload_summary_contract_valid($s) | not) then
          {
            sequence:$stage.sequence,label:$stage.label,condition:$stage.condition,
            phase:$stage.phase,rate_mbit:$stage.rate_mbit,
            sample_index:$stage.sample_index,round:$stage.round,
            evidence_contract_valid:false,
            evidence_contract_issues:["upload-summary-schema-or-qdisc-contract-invalid"],
            measurement_window_valid:false,
            measurement_window_status:"INVALID_EVIDENCE_CONTRACT",
            measurement_window_issues:["upload-summary-schema-or-qdisc-contract-invalid"],
            sender_seconds:null,receiver_seconds:null,sender_mbps:null,
            receiver_mbps_reported:null,receiver_mbps:null,
            sender_retransmits:null,sender_retransmits_per_gib:null,
            host_tcp_retrans_delta:null,host_tx_bytes_delta:null,
            qdisc_root_dropped_delta:null,qdisc_root_overlimits_delta:null,
            qdisc_root_requeues_delta:null,qdisc_leaf_dropped_delta:null,
            qdisc_leaf_requeues_delta:null,qdisc_topology:null,
            qdisc_health_status:"INVALID_EVIDENCE_CONTRACT",
            qdisc_health_valid:false,sender_rate_exposure_ratio:null,
            shaping_exposure_valid:false,cpu:$cpu,softnet:$softnet,
            link_drops_errors_delta:null,resource_gate_valid:false
          }
        else
        ($s.sender.mbps / $stage.rate_mbit) as $rate_exposure_ratio |
        ([$s.host.link_delta | to_entries[] |
          select((.key | endswith(".tx_dropped")) or
                 (.key | endswith(".rx_dropped")) or
                 (.key | endswith(".tx_errors")) or
                 (.key | endswith(".rx_errors"))) | .value] | add // 0) as $link_drops_errors |
        (($s.qdisc_root_totals.overlimits_delta > 0) and
         ($rate_exposure_ratio >= $p.controls.minimum_rate_exposure_ratio)) as $shaping_exposure_valid |
        ($s.qdisc_health.any_drop_or_requeue == false) as $qdisc_health_valid |
        (($cpu.idle_percent >= $p.controls.minimum_cpu_idle_percent) and
         ($cpu.steal_percent <= $p.controls.maximum_cpu_steal_percent) and
         ($softnet.dropped_delta == 0) and ($softnet.time_squeeze_delta == 0) and
         ($link_drops_errors == 0)) as $resource_gate_valid |
        {
          sequence:$stage.sequence,label:$stage.label,condition:$stage.condition,
          phase:$stage.phase,rate_mbit:$stage.rate_mbit,
           sample_index:$stage.sample_index,round:$stage.round,
           evidence_contract_valid:true,evidence_contract_issues:[],
          measurement_window_valid:$s.measurement_window.valid,
          measurement_window_status:$s.measurement_window.status,
          measurement_window_issues:$s.measurement_window.issues,
          sender_seconds:$s.sender.seconds,
          receiver_seconds:$s.receiver.seconds,
          sender_mbps:$s.sender.mbps,
          receiver_mbps_reported:$s.receiver.mbps,
          receiver_mbps:(if $s.measurement_window.valid then $s.receiver.mbps else null end),
          sender_retransmits:$s.sender.retransmits,
          sender_retransmits_per_gib:$s.sender.retransmits_per_gib,
          host_tcp_retrans_delta:($s.host.tcp_delta.TcpRetransSegs // null),
          host_tx_bytes_delta:$s.host.tx_bytes_delta,
           qdisc_root_dropped_delta:$s.qdisc_root_totals.dropped_delta,
           qdisc_root_overlimits_delta:$s.qdisc_root_totals.overlimits_delta,
           qdisc_root_requeues_delta:$s.qdisc_root_totals.requeues_delta,
           qdisc_leaf_dropped_delta:$s.qdisc_leaf_totals.dropped_delta,
           qdisc_leaf_requeues_delta:$s.qdisc_leaf_totals.requeues_delta,
           qdisc_topology:$s.qdisc_coverage.topology,
           qdisc_health_status:$s.qdisc_health.status,
           qdisc_health_valid:$qdisc_health_valid,
          sender_rate_exposure_ratio:$rate_exposure_ratio,
          shaping_exposure_valid:$shaping_exposure_valid,
          cpu:$cpu,softnet:$softnet,
          link_drops_errors_delta:$link_drops_errors,
          resource_gate_valid:$resource_gate_valid
        } end
      ' >>"$samples_file" || die "无法解析阶段摘要：${label}"
  done < <(jq -c '.stages[]' "$plan")

  jq -s --arg analyzer_version "$ANALYZER_VERSION" \
    --arg generated_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --slurpfile plan "$plan" '
      def median($values):
        ($values | map(select(type == "number")) | sort) as $v |
        ($v | length) as $n |
        if $n == 0 then null
        elif ($n % 2) == 1 then $v[($n / 2 | floor)]
        else (($v[$n/2 - 1] + $v[$n/2]) / 2) end;
      def stats($values):
        ($values | map(select(type == "number"))) as $v |
        (median($v)) as $m |
        {n:($v|length),min:(if ($v|length)>0 then ($v|min) else null end),
         max:(if ($v|length)>0 then ($v|max) else null end),median:$m,
         mad:(if $m == null then null else median($v | map((. - $m) | abs)) end)};
      def group_stats($rows):
        {samples:($rows|length),
         valid_evidence_contract_samples:([$rows[] | select(.evidence_contract_valid)] | length),
         valid_measurement_windows:([$rows[] | select(.measurement_window_valid)] | length),
         valid_shaping_exposure_samples:([$rows[] | select(.shaping_exposure_valid)] | length),
         valid_qdisc_health_samples:([$rows[] | select(.qdisc_health_valid)] | length),
         valid_resource_samples:([$rows[] | select(.resource_gate_valid)] | length),
         sender_mbps:stats([$rows[].sender_mbps]),
         sender_rate_exposure_ratio:stats([$rows[].sender_rate_exposure_ratio]),
         receiver_mbps:stats([$rows[].receiver_mbps]),
         sender_retransmits_per_gib:stats([$rows[].sender_retransmits_per_gib]),
         host_tcp_retrans_delta:stats([$rows[].host_tcp_retrans_delta]),
         qdisc_root_dropped_delta:stats([$rows[].qdisc_root_dropped_delta]),
         qdisc_root_overlimits_delta:stats([$rows[].qdisc_root_overlimits_delta]),
         qdisc_root_requeues_delta:stats([$rows[].qdisc_root_requeues_delta]),
         qdisc_leaf_dropped_delta:stats([$rows[].qdisc_leaf_dropped_delta]),
         qdisc_leaf_requeues_delta:stats([$rows[].qdisc_leaf_requeues_delta]),
         cpu_idle_percent:stats([$rows[].cpu.idle_percent]),
         cpu_steal_percent:stats([$rows[].cpu.steal_percent]),
         softnet_dropped_delta:stats([$rows[].softnet.dropped_delta]),
         softnet_time_squeeze_delta:stats([$rows[].softnet.time_squeeze_delta]),
         link_drops_errors_delta:stats([$rows[].link_drops_errors_delta])};
      def overlap($a; $b):
        if ($a.median == null or $a.mad == null or $b.median == null or $b.mad == null) then false
        else ([($a.median - $a.mad), ($b.median - $b.mad)] | max) <=
             ([($a.median + $a.mad), ($b.median + $b.mad)] | min)
        end;
      . as $samples |
      $plan[0] as $plan_doc |
      ([$samples[] | select(.evidence_contract_valid != true)]) as $invalid_contract_rows |
      (($invalid_contract_rows | length) > 0) as $evidence_contract_blocked |
      ([$samples[] | select(.measurement_window_valid != true)]) as $invalid_rows |
      (($invalid_rows | length) > 0) as $measurement_blocked |
      ([$samples[] | select(.shaping_exposure_valid != true)]) as $invalid_exposure_rows |
      (($invalid_exposure_rows | length) > 0) as $exposure_blocked |
      ([$samples[] | select(.qdisc_health_valid != true)]) as $invalid_qdisc_rows |
      (($invalid_qdisc_rows | length) > 0) as $qdisc_health_blocked |
      ([$samples[] | select(.resource_gate_valid != true)]) as $invalid_resource_rows |
      (($invalid_resource_rows | length) > 0) as $resource_blocked |
      ($evidence_contract_blocked or $measurement_blocked or $exposure_blocked or
       $qdisc_health_blocked or $resource_blocked) as $analysis_blocked |
      ([$samples[] | select(.condition == "reference-htb")]) as $reference_rows |
      (group_stats($reference_rows)) as $reference_all |
      ([$samples[] | select(.phase == "reference-start")]) as $reference_start_rows |
      ([$samples[] | select(.phase == "reference-end")]) as $reference_end_rows |
      (group_stats($reference_start_rows)) as $reference_start |
      (group_stats($reference_end_rows)) as $reference_end |
      ([$samples[] | select(.condition == "candidate-htb")] |
        group_by(.rate_mbit) |
        map({rate_mbit:.[0].rate_mbit} + group_stats(.)) |
        sort_by(.rate_mbit)) as $rates |
      (if $plan_doc.mode == "candidate-sweep" then
         overlap($reference_start.sender_mbps; $reference_end.sender_mbps) and
         overlap($reference_start.sender_retransmits_per_gib;
                 $reference_end.sender_retransmits_per_gib)
       else null end) as $reference_comparable |
      (if ($rates | length) > 0 then ($rates | max_by(.sender_mbps.median)) else null end) as $best_sender_group |
      (if $plan_doc.mode == "candidate-sweep" then
         [$rates[] |
          . as $g |
          ($reference_all.sender_retransmits_per_gib.median -
           $reference_all.sender_retransmits_per_gib.mad) as $reference_retrans_lower |
          ($g.sender_retransmits_per_gib.median +
           $g.sender_retransmits_per_gib.mad) as $group_retrans_upper |
          ($best_sender_group.sender_mbps.median -
           ([$best_sender_group.sender_mbps.mad, $g.sender_mbps.mad] | max)) as $near_best_floor |
          . + {review_flags:{
            retransmission_below_reference_dispersion:($group_retrans_upper < ([0,$reference_retrans_lower]|max)),
            sender_goodput_within_observed_best_dispersion:($g.sender_mbps.median >= $near_best_floor),
            all_evidence_contracts_valid:($g.valid_evidence_contract_samples == $g.samples),
            all_receiver_measurement_windows_valid:($g.valid_measurement_windows == $g.samples),
            all_local_qdisc_health_samples_valid:($g.valid_qdisc_health_samples == $g.samples),
            all_htb_overlimit_samples_positive:($g.qdisc_root_overlimits_delta.min > 0),
            all_sender_rate_exposure_samples_valid:($g.valid_shaping_exposure_samples == $g.samples),
            all_resource_samples_valid:($g.valid_resource_samples == $g.samples)
          }}]
       else [] end) as $rates_with_flags |
      (if $plan_doc.mode == "candidate-sweep" and ($analysis_blocked | not) and $reference_comparable then
         [$rates_with_flags[] | select(
           .review_flags.retransmission_below_reference_dispersion and
           .review_flags.sender_goodput_within_observed_best_dispersion and
           .review_flags.all_evidence_contracts_valid and
           .review_flags.all_receiver_measurement_windows_valid and
           .review_flags.all_local_qdisc_health_samples_valid and
           .review_flags.all_htb_overlimit_samples_positive and
           .review_flags.all_sender_rate_exposure_samples_valid and
           .review_flags.all_resource_samples_valid)]
       else [] end) as $shortlist |
      {
        schema_version:3,
        analyzer_version:$analyzer_version,
        generated_utc:$generated_utc,
        plan_mode:$plan_doc.mode,
        status:(if $analysis_blocked then "REVIEW_BLOCKED" else "REVIEW_REQUIRED" end),
        persistence_authorized:false,
        evidence_contract_gate:{
          valid:(($evidence_contract_blocked | not)),
          required_upload_summary_schema:3,
          requires_htb_fq_topology:true,
          requires_root_and_leaf_qdisc_health:true,
          invalid_sample_count:($invalid_contract_rows | length),
          invalid_samples:[$invalid_contract_rows[] | {
            sequence,label,condition,rate_mbit,issues:.evidence_contract_issues}],
          invalid_sample_effect:"REVIEW_BLOCKED; old or incomplete summaries must be regenerated"
        },
        measurement_gate:{
          valid:(($measurement_blocked | not)),
          invalid_sample_count:($invalid_rows | length),
          invalid_samples:[$invalid_rows[] | {
            sequence,label,condition,rate_mbit,sender_seconds,receiver_seconds,
            receiver_mbps_reported,issues:.measurement_window_issues}],
          invalid_sample_effect:"REVIEW_BLOCKED; no shortlist is eligible"
        },
        shaping_exposure_gate:{
          valid:(($exposure_blocked | not)),
          minimum_sender_rate_exposure_ratio:$plan_doc.controls.minimum_rate_exposure_ratio,
          requires_positive_overlimits_each_sample:true,
          invalid_sample_count:($invalid_exposure_rows | length),
          invalid_samples:[$invalid_exposure_rows[] | {
            sequence,label,condition,rate_mbit,sender_mbps,
            sender_rate_exposure_ratio,qdisc_root_overlimits_delta}],
          invalid_sample_effect:"REVIEW_BLOCKED; generate a new fixed-parallel plan instead of ranking unexposed rates"
        },
        qdisc_health_gate:{
          valid:(($qdisc_health_blocked | not)),
          requires_zero_root_drops:true,
          requires_zero_root_requeues:true,
          requires_zero_leaf_drops:true,
          requires_zero_leaf_requeues:true,
          invalid_sample_count:($invalid_qdisc_rows | length),
          invalid_samples:[$invalid_qdisc_rows[] | {
            sequence,label,condition,rate_mbit,qdisc_topology,qdisc_health_status,
            qdisc_root_dropped_delta,qdisc_root_requeues_delta,
            qdisc_leaf_dropped_delta,qdisc_leaf_requeues_delta}],
          invalid_sample_effect:"REVIEW_BLOCKED; inspect local root and leaf queue counters before ranking rates"
        },
        resource_gate:{
          valid:(($resource_blocked | not)),
          minimum_cpu_idle_percent:$plan_doc.controls.minimum_cpu_idle_percent,
          maximum_cpu_steal_percent:$plan_doc.controls.maximum_cpu_steal_percent,
          requires_zero_softnet_drops:true,
          requires_zero_softnet_time_squeeze:true,
          requires_zero_link_drops_errors:true,
          invalid_sample_count:($invalid_resource_rows | length),
          invalid_samples:[$invalid_resource_rows[] | {
            sequence,label,condition,rate_mbit,cpu,softnet,link_drops_errors_delta}],
          invalid_sample_effect:"REVIEW_BLOCKED; diagnose the 1-vCPU or link resource bottleneck"
        },
        metric_contract:{
          primary_throughput_metric:"iperf3 sender Mbit/s in a validated measurement window",
          primary_retransmission_metric:"iperf3 sender retransmits per exact sender GiB",
          receiver_metric:"corroborating iperf3 receiver goodput; excluded unless its window validates",
          packet_loss_percentage_inferred:false,
          fixed_mss_assumed:false,
          fixed_global_retransmission_threshold_used:false
        },
        reference:{rate_mbit:$plan_doc.reference_rate_mbit,all:$reference_all,
          start:(if $plan_doc.mode == "candidate-sweep" then $reference_start else null end),
          end:(if $plan_doc.mode == "candidate-sweep" then $reference_end else null end),
          comparable_by_sender_median_mad_overlap:$reference_comparable},
        source_reference_gate:$plan_doc.reference_gate,
        rates:$rates_with_flags,
        review_shortlist:{
          rate_mbit:(if ($shortlist|length)>0 then ($shortlist|max_by(.rate_mbit)|.rate_mbit) else null end),
          eligible_rates_mbit:[$shortlist[].rate_mbit],
          meaning:(if $plan_doc.mode == "reference-screen" then
            "reference screen has no candidate shortlist; manual review decides whether to stop or authorize candidate-sweep"
          else "highest rate passing strict descriptive gates; not a production recommendation" end)
        },
        required_manual_review:[
          "inspect every raw iperf3 JSON and benchmark completion hash",
          "compare host-wide TcpRetransSegs with flow-scoped sender retransmits",
          "inspect CPU softirq and steal, softnet drops/time_squeeze, interface errors and qdisc backlog/requeues",
          "confirm endpoint, address family, tool hashes, route, workload and time-window comparability",
          "reject or repeat the run when measurement windows, reference drift or sample dispersion are operationally material"
        ],
        next_gate:(if $evidence_contract_blocked then
          "regenerate every stage with upload summary schema 3 and complete HTB root/FQ leaf counters"
        elif $measurement_blocked then
          "preserve evidence, diagnose the invalid iperf3 measurement window, and repeat with a new evidence directory"
        elif $exposure_blocked then
          "do not rank rates; preserve evidence and generate a new complete plan with a fixed higher parallel count or a different authorized endpoint"
        elif $qdisc_health_blocked then
          "do not rank rates; inspect root/leaf qdisc drops and requeues before creating a new evidence directory"
        elif $resource_blocked then
          "do not rank rates; diagnose CPU steal/idle, softnet or link counters before creating a new evidence directory"
        elif $plan_doc.mode == "reference-screen" then
          "manually review HTB200 retransmission stability; stop when acceptable, otherwise explicitly authorize a candidate-sweep plan"
        else
          "freeze a reviewed shortlist rate, then run independent A/B/A and reverse-window replication" end),
        interpretation:{
          htb_effect:"may support a local-egress burst/policer hypothesis but cannot by itself prove provider policing",
          overlimits:"expected evidence that HTB acted; not packet loss",
          shaping_exposure:"positive overlimits plus sender goodput at the frozen rate-exposure ratio is required for every sample",
          local_qdisc_health:"zero root/leaf drops and requeues do not exclude downstream or remote-path loss",
          success_boundary:"completion and a shortlist do not prove proxy business-path improvement"
        },
        traffic_budget:$plan_doc.traffic_budget,
        samples:$samples
      }
    ' "$samples_file"
  rm -f -- "$samples_file"
  trap - EXIT INT TERM
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi

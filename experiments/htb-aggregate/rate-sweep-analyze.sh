#!/usr/bin/env bash
# Build robust descriptive statistics from a completed rate-sweep evidence tree.
# The output is a review shortlist, never an automatic production recommendation.

set -Eeuo pipefail
IFS=$'\n\t'
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

ANALYZER_VERSION='0.1.0'

die() { printf '[rate-sweep-analyze][FAIL] %s\n' "$*" >&2; exit 1; }

main() {
  local evidence_dir="${1:-}" plan samples_file stage_json sequence label stage_dir benchmark_dir
  local stage_result_sha actual_result_sha actual_manifest_sha
  [ "$#" -eq 1 ] || die '用法：rate-sweep-analyze.sh /absolute/completed-or-in-progress-sweep-dir'
  command -v jq >/dev/null 2>&1 || die '缺少命令：jq'
  command -v sha256sum >/dev/null 2>&1 || die '缺少命令：sha256sum'
  [[ "$evidence_dir" = /* ]] || die '证据目录必须是绝对路径。'
  [ -d "$evidence_dir" ] || die "证据目录不存在：${evidence_dir}"
  plan="${evidence_dir}/plan.json"
  [ -s "$plan" ] || die '缺少 plan.json。'
  jq -e '
    .schema_version == 1 and .mode == "candidate-rate-discovery-plan" and
    .scope.direction == "upload" and .scope.persistent_shaping_authorized == false and
    (.rates_mbit | type == "array" and length >= 3 and length <= 8) and
    ((.rates_mbit | length) == (.rates_mbit | unique | length)) and
    (.controls.samples_per_state | type == "number" and floor == . and . >= 2 and . <= 5) and
    (.stages | type == "array" and length >= 10 and length <= 50) and
    ((.stages | length) == (.controls.samples_per_state * ((.rates_mbit | length) + 2))) and
    ([.stages[].sequence] == [range(1; (.stages|length) + 1)]) and
    (([.stages[].label] | length) == ([.stages[].label] | unique | length)) and
    all(.stages[];
      (.condition == "baseline-fq" and .rate_mbit == null) or
      (.condition == "candidate-htb" and (.rate_mbit | type == "number" and floor == . and . >= 100 and . <= 199)))
  ' "$plan" >/dev/null || die 'plan.json 不符合候选扫描 schema。'

  samples_file="$(mktemp)"
  trap 'rm -f -- "$samples_file"' EXIT INT TERM
  while IFS= read -r stage_json; do
    sequence="$(jq -r '.sequence' <<<"$stage_json")"
    label="$(jq -r '.label' <<<"$stage_json")"
    stage_dir="${evidence_dir}/stages/$(printf '%02d-%s' "$sequence" "$label")"
    benchmark_dir="${stage_dir}/benchmark"
    [ -s "${stage_dir}/stage-result.json" ] || die "缺少阶段结果：${label}"
    jq -e --argjson expected "$stage_json" '
      .schema_version == 1 and .status == "PASS" and
      .plan_stage == $expected and .qdisc_restored_to_root_fq == true and
      .persistent_shaping_created == false and
      (.benchmark_result_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    ' "${stage_dir}/stage-result.json" >/dev/null || die "阶段结果内容无效：${label}"
    [ -f "${benchmark_dir}/COMPLETED" ] && [ ! -f "${benchmark_dir}/INCOMPLETE" ] ||
      die "benchmark 未完成：${label}"
    [ -s "${benchmark_dir}/upload.summary.json" ] || die "缺少 upload.summary.json：${label}"
    [ -s "${benchmark_dir}/benchmark-result.json" ] || die "缺少 benchmark-result.json：${label}"
    (
      cd "$benchmark_dir"
      sha256sum -c SHA256SUMS >/dev/null
    ) || die "benchmark manifest 校验失败：${label}"
    jq -e '.schema_version == 1 and .status == "PASS" and .exit_code == 0 and
      .phases.upload != null and .phases.download == null' \
      "${benchmark_dir}/benchmark-result.json" >/dev/null || die "benchmark-result 无效：${label}"
    stage_result_sha="$(jq -r '.benchmark_result_sha256 // empty' "${stage_dir}/stage-result.json")"
    actual_result_sha="$(sha256sum "${benchmark_dir}/benchmark-result.json" | awk '{print $1}')"
    actual_manifest_sha="$(sha256sum "${benchmark_dir}/SHA256SUMS" | awk '{print $1}')"
    [ "$stage_result_sha" = "$actual_result_sha" ] || die "阶段结果与 benchmark hash 不匹配：${label}"
    grep -Fxq "result_sha256=${actual_result_sha}" "${benchmark_dir}/COMPLETED" ||
      die "COMPLETED 未绑定 benchmark-result：${label}"
    grep -Fxq "evidence_manifest_sha256=${actual_manifest_sha}" \
      "${benchmark_dir}/COMPLETED" || die "COMPLETED 未绑定 benchmark manifest：${label}"
    jq -n --argjson stage "$stage_json" \
      --slurpfile summary "${benchmark_dir}/upload.summary.json" '
        ($summary[0]) as $s |
        if ($s | type) != "object" or $s.direction != "upload" or $s.reverse != false then
          error("upload summary is invalid")
        else {
          sequence:$stage.sequence,label:$stage.label,condition:$stage.condition,
          phase:$stage.phase,rate_mbit:$stage.rate_mbit,
          sample_index:$stage.sample_index,round:$stage.round,
          sender_mbps:$s.sender.mbps,
          receiver_mbps:$s.receiver.mbps,
          sender_retransmits:$s.sender.retransmits,
          sender_retransmits_per_gib:$s.sender.retransmits_per_gib,
          host_tcp_retrans_delta:($s.host.tcp_delta.TcpRetransSegs // null),
          host_tx_bytes_delta:$s.host.tx_bytes_delta,
          qdisc_dropped_delta:$s.qdisc_active_totals.dropped_delta,
          qdisc_overlimits_delta:$s.qdisc_active_totals.overlimits_delta,
          qdisc_requeues_delta:$s.qdisc_active_totals.requeues_delta,
          qdisc_aggregation_source:$s.qdisc_coverage.aggregation_source
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
         sender_mbps:stats([$rows[].sender_mbps]),
         receiver_mbps:stats([$rows[].receiver_mbps]),
         sender_retransmits_per_gib:stats([$rows[].sender_retransmits_per_gib]),
         host_tcp_retrans_delta:stats([$rows[].host_tcp_retrans_delta]),
         qdisc_dropped_delta:stats([$rows[].qdisc_dropped_delta]),
         qdisc_overlimits_delta:stats([$rows[].qdisc_overlimits_delta]),
         qdisc_requeues_delta:stats([$rows[].qdisc_requeues_delta])};
      def overlap($a; $b):
        if ($a.median == null or $a.mad == null or $b.median == null or $b.mad == null) then false
        else ([($a.median - $a.mad), ($b.median - $b.mad)] | max) <=
             ([($a.median + $a.mad), ($b.median + $b.mad)] | min)
        end;
      . as $samples |
      ([$samples[] | select(.phase == "baseline-start")]) as $baseline_start_rows |
      ([$samples[] | select(.phase == "baseline-end")]) as $baseline_end_rows |
      (($baseline_start_rows + $baseline_end_rows)) as $baseline_rows |
      (group_stats($baseline_start_rows)) as $baseline_start |
      (group_stats($baseline_end_rows)) as $baseline_end |
      (group_stats($baseline_rows)) as $baseline_combined |
      ([$samples[] | select(.condition == "candidate-htb")] |
        group_by(.rate_mbit) |
        map({rate_mbit:.[0].rate_mbit} + group_stats(.)) |
        sort_by(.rate_mbit)) as $rates |
      (overlap($baseline_start.receiver_mbps; $baseline_end.receiver_mbps) and
       overlap($baseline_start.sender_retransmits_per_gib;
               $baseline_end.sender_retransmits_per_gib)) as $baseline_comparable |
      ($rates | max_by(.receiver_mbps.median)) as $best_receiver_group |
      ([$rates[] |
        . as $g |
        ($baseline_combined.sender_retransmits_per_gib.median -
         $baseline_combined.sender_retransmits_per_gib.mad) as $baseline_retrans_lower |
        ($g.sender_retransmits_per_gib.median +
         $g.sender_retransmits_per_gib.mad) as $group_retrans_upper |
        ($best_receiver_group.receiver_mbps.median -
         ([$best_receiver_group.receiver_mbps.mad, $g.receiver_mbps.mad] | max)) as $near_best_floor |
        . + {review_flags:{
          retransmission_below_baseline_dispersion:($group_retrans_upper < ([0,$baseline_retrans_lower]|max)),
          receiver_goodput_within_observed_best_dispersion:($g.receiver_mbps.median >= $near_best_floor),
          all_local_qdisc_drop_samples_zero:($g.qdisc_dropped_delta.max == 0)
        }}]) as $rates_with_flags |
      (if $baseline_comparable then
         [$rates_with_flags[] | select(
           .review_flags.retransmission_below_baseline_dispersion and
           .review_flags.receiver_goodput_within_observed_best_dispersion and
           .review_flags.all_local_qdisc_drop_samples_zero)]
       else [] end) as $shortlist |
      {
        schema_version:1,
        analyzer_version:$analyzer_version,
        generated_utc:$generated_utc,
        status:"REVIEW_REQUIRED",
        persistence_authorized:false,
        metric_contract:{
          primary_retransmission_metric:"iperf3 sender retransmits per exact sender GiB",
          receiver_metric:"iperf3 receiver goodput in Mbit/s",
          packet_loss_percentage_inferred:false,
          fixed_mss_assumed:false,
          fixed_global_retransmission_threshold_used:false
        },
        baseline:{start:$baseline_start,end:$baseline_end,combined:$baseline_combined,
          comparable_by_median_mad_overlap:$baseline_comparable},
        rates:$rates_with_flags,
        review_shortlist:{
          rate_mbit:(if ($shortlist|length)>0 then ($shortlist|max_by(.rate_mbit)|.rate_mbit) else null end),
          eligible_rates_mbit:[$shortlist[].rate_mbit],
          meaning:"highest rate passing strict descriptive shortlist gates; not a production recommendation"
        },
        required_manual_review:[
          "inspect every raw iperf3 JSON and benchmark completion hash",
          "compare host-wide TcpRetransSegs with flow-scoped sender retransmits",
          "inspect CPU softirq and steal, softnet drops/time_squeeze, interface errors and qdisc backlog/requeues",
          "confirm endpoint, address family, tool hashes, route, workload and time-window comparability",
          "reject the sweep when baseline drift or sample dispersion is operationally material"
        ],
        next_gate:"freeze a reviewed shortlist rate, then run independent A/B/A and reverse-window replication with the existing experiment plan",
        interpretation:{
          htb_effect:"may support a local-egress burst/policer hypothesis but cannot by itself prove provider policing",
          overlimits:"expected evidence that HTB acted; not packet loss",
          local_qdisc_drops:"zero local drops do not exclude downstream or remote-path loss",
          success_boundary:"sweep completion and a shortlist do not prove proxy business-path improvement"
        },
        traffic_budget:$plan[0].traffic_budget,
        samples:$samples
      }
    ' "$samples_file"
  rm -f -- "$samples_file"
  trap - EXIT INT TERM
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi

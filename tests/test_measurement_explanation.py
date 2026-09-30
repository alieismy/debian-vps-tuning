"""合成边界场景只验证离线解释契约，不代表公网分类准确率。"""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('explanation', ROOT / 'tools/explain_measurement.py')
e = importlib.util.module_from_spec(spec)
spec.loader.exec_module(e)


def fixture(pattern='isolated', schema='dvt.path-measurement/1'):
    # 手工指定合成计数和原分类，不用本次实测的 12 Mbps 样本选择测试阈值。
    sequences = {'clean': ([0, 0, 0], [0, 0, 0]),
                 'isolated': ([1, 0, 1], [0, 0, 0]),
                 'sustained': ([8, 9, 8], [12, 10, 12]),
                 'highest': ([0, 0, 0], [8, 8, 0])}
    low, high = sequences[pattern]
    rows = []
    for role, rate, counts in (('control-start', 10, [0]*3), ('sweep', 20, low),
                               ('sweep', 40, high), ('control-end', 10, [0]*3)):
        for count in counts:
            rows.append(dict(role=role, rate_mbps=rate, eligible=True,
                             sender=dict(bytes=8*2**20, retransmits=count, retransmits_per_gib=count*128)))
    candidate = None if pattern == 'clean' else dict(lower_mbps=20 if pattern == 'highest' else 10,
                                                    upper_mbps=40 if pattern == 'highest' else 20)
    groups = [dict(rate_mbps=20, eligible=True, status='RETRANSMISSION_RISE' if pattern in ('isolated', 'sustained') else 'NO_CONFIRMED_RISE'),
              dict(rate_mbps=40, eligible=True, status='RETRANSMISSION_RISE' if pattern in ('sustained', 'highest') else 'NO_CONFIRMED_RISE')]
    return dict(schema=schema, version='fixture', stop_reason=None, endpoint=None, samples=rows,
                analysis=dict(status='RETRANSMISSION_RISE_OBSERVED' if candidate else 'NO_RISE_IN_TESTED_RANGE',
                              candidate_interval=candidate, tested_rates=groups, issues=[],
                              spike_threshold_retransmits_per_gib=100, policer_identified=False,
                              recommended_shaping_rate_mbps=None))


class ExplanationTests(unittest.TestCase):
    def test_isolated_single_events_keep_original_candidate(self):
        source = fixture(); before = copy.deepcopy(source)
        result = e.explain(source)
        self.assertEqual(source, before)
        self.assertEqual(result['original_analysis'], before['analysis'])
        observed = result['candidate_observation']
        self.assertEqual((observed['threshold_hits'], observed['single_event_hits']), (2, 2))
        self.assertEqual(observed['higher_rate_observation'], 'NO_CONFIRMED_RISE')
        self.assertEqual(result['independent_replication'], 'NOT_ASSESSED')

    def test_sustained_rise_does_not_become_policer_proof(self):
        result = e.explain(fixture('sustained'))
        self.assertEqual(result['candidate_observation']['higher_rate_observation'], 'RISE_OBSERVED')
        self.assertEqual(result['candidate_observation']['single_event_hits'], 0)
        self.assertFalse(result['original_analysis']['policer_identified'])
        self.assertEqual(result['htb_entry'], 'NOT_ESTABLISHED_BY_SINGLE_REPORT')

    def test_highest_candidate_has_no_higher_counterevidence(self):
        result = e.explain(fixture('highest'))
        self.assertEqual(result['candidate_observation']['higher_rate_observation'], 'NOT_COVERED')

    def test_missing_high_rate_is_incomplete_not_clean(self):
        source = fixture(); source['analysis']['tested_rates'][1]['eligible'] = False
        self.assertEqual(e.explain(source)['candidate_observation']['higher_rate_observation'], 'INCOMPLETE')

    def test_missing_rate_summary_does_not_claim_no_coverage(self):
        for pattern in ('isolated', 'highest'):
            with self.subTest(pattern=pattern):
                source = fixture(pattern); del source['analysis']['tested_rates']
                self.assertEqual(e.explain(source)['candidate_observation']['higher_rate_observation'], 'INCOMPLETE')

    def test_omitted_higher_sample_rate_is_incomplete(self):
        source = fixture(); source['analysis']['tested_rates'].pop()
        self.assertEqual(e.explain(source)['candidate_observation']['higher_rate_observation'], 'INCOMPLETE')

    def test_no_candidate_and_partial_keep_original_refusal(self):
        for stop in (None, 'TIME_LIMIT', 'BUDGET_LIMIT'):
            source = fixture('clean'); source['stop_reason'] = stop
            if stop: source['analysis'].update(status='INSUFFICIENT_EVIDENCE', issues=['INCOMPLETE_SWEEP'])
            result = e.explain(source)
            self.assertIsNone(result['candidate_observation'])
            self.assertEqual(result['original_stop_reason'], stop)
            self.assertEqual(result['original_analysis'], source['analysis'])

    def test_no_endpoint_empty_report_can_be_explained(self):
        source = fixture('clean'); source['samples'] = []
        source['analysis'].update(status='INSUFFICIENT_EVIDENCE', spike_threshold_retransmits_per_gib=None, tested_rates=[])
        self.assertEqual(e.explain(source)['samples'], [])

    def test_missing_counts_remain_unknown(self):
        source = fixture(); del source['samples'][3]['sender']['retransmits']
        result = e.explain(source)
        self.assertEqual(result['samples'][3]['status'], 'UNAVAILABLE')
        self.assertIsNone(result['candidate_observation']['threshold_hits'])
        with redirect_stdout(io.StringIO()) as out: e.print_explanation(result)
        self.assertIn('不能评估触发强度', out.getvalue())

    def test_integer_threshold_exact_and_just_above_boundary(self):
        for size, expected in ((2**30, 100), (2**30+1, 101)):
            source = fixture('clean'); source['samples'][0]['sender'] = dict(bytes=size, retransmits=0)
            self.assertEqual(e.explain(source)['samples'][0]['events_at_threshold'], expected)

    def test_invalid_counts_bytes_and_rates_are_rejected(self):
        for field, values in (('bytes', [True, 0, -1, 1.5, float('inf')]),
                              ('retransmits', [False, -1, 0.5, float('nan')])):
            for value in values:
                with self.subTest(field=field, value=value):
                    source = fixture(); source['samples'][0]['sender'][field] = value
                    with self.assertRaises(ValueError): e.explain(source)
        for value in (True, -1, float('nan'), float('inf')):
            source = fixture(); source['samples'][0]['rate_mbps'] = value
            with self.assertRaises(ValueError): e.explain(source)

    def test_conflicting_normalization_is_rejected(self):
        source = fixture(); source['samples'][0]['sender']['retransmits_per_gib'] = 100
        with self.assertRaises(ValueError): e.explain(source)

    def test_reference_samples_do_not_count_as_sweep(self):
        source = fixture(schema='dvt.htb-measurement/1')
        reference = copy.deepcopy(source['samples'][3]); reference['role'] = 'reference-start'
        source['samples'] += [reference]*3
        self.assertEqual(e.explain(source)['candidate_observation']['threshold_hits'], 2)

    def make_report(self, directory, source):
        (directory / 'INCOMPLETE').write_text('fixture', encoding='utf-8')
        (directory / 'plan.json').write_text('{}', encoding='utf-8')
        (directory / 'measurement-result.json').write_text(json.dumps(source), encoding='utf-8')
        e.measurement.finalize_evidence(directory)

    def test_cli_roundtrip_is_deterministic_and_read_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp); self.make_report(directory, fixture())
            before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.iterdir()}
            texts = []
            for _ in range(2):
                out = io.StringIO()
                with redirect_stdout(out): code = e.main(['--input-dir', tmp, '--json'])
                self.assertEqual(code, 0); texts.append(out.getvalue())
            self.assertEqual(texts[0], texts[1])
            self.assertEqual(json.loads(texts[0])['source']['schema'], 'dvt.path-measurement/1')
            with redirect_stdout(io.StringIO()) as out: self.assertEqual(e.main(['--input-dir', tmp]), 0)
            self.assertIn('原候选保留', out.getvalue())
            self.assertEqual(before, {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.iterdir()})

    def test_tamper_and_incomplete_produce_no_json(self):
        for mode in ('tamper', 'incomplete'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp); self.make_report(directory, fixture())
                if mode == 'tamper': (directory / 'measurement-result.json').write_text('{}', encoding='utf-8')
                else: (directory / 'INCOMPLETE').write_text('interrupted', encoding='utf-8')
                with redirect_stdout(io.StringIO()) as out, redirect_stderr(io.StringIO()):
                    self.assertEqual(e.main(['--input-dir', tmp, '--json']), 2)
                self.assertEqual(out.getvalue(), '')

    def test_htb_recovery_requirement_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp); source = fixture(schema='dvt.htb-measurement/1'); source['endpoint'] = {'id': 'fixture'}
            self.make_report(directory, source)
            with redirect_stderr(io.StringIO()): self.assertEqual(e.main(['--input-dir', tmp]), 2)
            state = directory / 'htb-transaction/state.json'; state.parent.mkdir(); state.write_text('{"phase":"RESTORED"}', encoding='utf-8')
            (directory / 'INCOMPLETE').write_text('fixture update', encoding='utf-8')
            e.measurement.finalize_evidence(directory)
            self.assertEqual(e.explain_directory(directory)['source']['schema'], 'dvt.htb-measurement/1')


if __name__ == '__main__':
    unittest.main()

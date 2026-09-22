"""直接执行目标 Shell 函数和 jq 分析程序；不调用生产 main。"""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "tools/profile-template.sh.in").read_text(encoding="utf-8")


def function(name):
    return re.search(r"^" + name + r"\(\) \{.*?^\}", SOURCE, re.M | re.S).group()


@unittest.skipUnless(shutil.which("bash"), "Bash is required")
class ShellAdoptionTest(unittest.TestCase):
    def bash(self, script):
        result = subprocess.run([shutil.which("bash")], input=script.encode(), capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        return result.stdout.decode()

    def test_swap_long_list_and_producer_error(self):
        expressions = re.findall(r"swapon --show=NAME --noheadings[^\n]*?\| grep[^;\n]+", SOURCE)
        self.assertEqual(len(expressions), 4)
        expressions = [e.split(" || ")[0].removesuffix("; then").strip() for e in expressions]
        producer = r'''
set -uo pipefail
SWAP_FILE=/swapfile.proxy-vps-tuning
swapon() {
  local part tail i
  printf -v part '%0200d' 0
  tail="/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part/$part"
  printf '%s\n' "$SWAP_FILE"
  sleep 0.05
  for ((i=1;i<=28;i++)); do printf '%s/swap-%s\n' "$tail" "$i"; done
}
'''
        self.bash(producer + "\n".join(f"{e}\n[ $? = 0 ] || exit 1" for e in expressions))
        self.bash("set -uo pipefail\nSWAP_FILE=/swapfile.proxy-vps-tuning\n"
                  "swapon() { printf '%s\\n' \"$SWAP_FILE\"; return 7; }\n" +
                  "\n".join(f"{e}\n[ $? = 7 ] || exit 1" for e in expressions))
        self.bash("set -uo pipefail\nSWAP_FILE=/swapfile.proxy-vps-tuning\nswapon() { :; }\n" +
                  "\n".join(f"{e}\n[ $? = 1 ] || exit 1" for e in expressions))

    def test_lock_conflict_identity_and_read_only_fallback(self):
        code = function("lock_conflict_details") + "\n" + function("acquire_lock")
        self.bash(code + r'''
set -euo pipefail
LOCK_FILE=$(mktemp)
trap 'rm -f "$LOCK_FILE"' EXIT
EXIT_CONFLICT=4
die() { local rc="$1"; shift; printf '%s\n' "$*"; exit "$rc"; }
lock_process_start() { printf '%s\n' 456; }
lock_uptime_seconds() { printf '%s\n' 110; }
flock() { return 1; }
printf '123 456 100\n' >"$LOCK_FILE"
if output=$(acquire_lock); then exit 1; else [ $? = 4 ]; fi
[[ "$output" == *'owner_pid=123 held_seconds=10'* ]]
[[ $(cat "$LOCK_FILE") == '123 456 100' ]]
printf '123 999 100\n' >"$LOCK_FILE"
[[ -z $(lock_conflict_details) ]]
printf 'malformed\n' >"$LOCK_FILE"
[[ -z $(lock_conflict_details) ]]
flock() { return 0; }
owner=$BASHPID
acquire_lock
[[ $(cat "$LOCK_FILE") == "$owner 456 110" ]]
''')

    def test_real_flock_contention_when_available(self):
        check = subprocess.run([shutil.which("bash"), "-c", "command -v flock >/dev/null"], capture_output=True)
        if check.returncode:
            self.skipTest("当前宿主缺少 flock；真实竞争由 Linux 门禁执行")
        code = "\n".join(function(name) for name in
                         ("lock_process_start", "lock_uptime_seconds", "lock_conflict_details", "acquire_lock"))
        self.bash(code + r'''
set -euo pipefail
LOCK_FILE=$(mktemp)
trap 'rm -f "$LOCK_FILE"' EXIT
EXIT_CONFLICT=4
die() { local rc="$1"; shift; printf '%s\n' "$*"; exit "$rc"; }
owner=$BASHPID
acquire_lock
[[ $(cat "$LOCK_FILE") == "$owner "* ]]
if output=$(exec 9>&-; acquire_lock); then exit 1; else [ $? = 4 ]; fi
[[ "$output" == *"owner_pid=$owner held_seconds="* ]]
''')


@unittest.skipUnless(shutil.which("jq"), "jq is required")
class ReceiverReviewTest(unittest.TestCase):
    def analyze(self, receiver=188, invalid=False, drift=False):
        source = (ROOT / "experiments/htb-aggregate/rate-sweep-analyze.sh").read_text(encoding="utf-8")
        program = source.split("--slurpfile plan \"$plan\" '\n      def median", 1)[1]
        program = "def median" + program.split("' \"$samples_file\"", 1)[0]
        rows = []
        for phase, rate, sender, received in [("reference-start", 200, 199, 198),
                                             ("candidate-sweep", 180, 180, 178),
                                             ("candidate-sweep", 190, 190, receiver),
                                             ("reference-end", 200, 199, 160 if drift else 198)]:
            for sample in range(3):
                rows.append(dict(phase=phase, rate_mbit=rate,
                    condition="candidate-htb" if phase == "candidate-sweep" else "reference-htb",
                    evidence_contract_valid=True, measurement_window_valid=not invalid,
                    shaping_exposure_valid=True, qdisc_health_valid=True, resource_gate_valid=True,
                    sender_mbps=sender, receiver_mbps=received,
                    sender_retransmits_per_gib=100 if rate == 200 else 10,
                    qdisc_root_overlimits_delta=100))
        plan = {"mode": "candidate-sweep", "reference_rate_mbit": 200, "controls": {}}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "analysis.jq"
            path.write_text(program, encoding="utf-8")
            result = subprocess.run([shutil.which("jq"), "-s", "--arg", "analyzer_version", "fixture",
                                     "--arg", "generated_utc", "fixture", "--argjson", "plan", json.dumps([plan]),
                                     "-f", str(path)], input="\n".join(json.dumps(row) for row in rows).encode(),
                                    capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        return json.loads(result.stdout)

    def test_divergence_is_advisory_and_shortlist_unchanged(self):
        normal = self.analyze()
        divergent = self.analyze(receiver=120)
        self.assertEqual(normal["review_shortlist"], divergent["review_shortlist"])
        self.assertEqual(divergent["rates"][1]["receiver_divergence_review"]["compared_rates_mbit"], [180])
        self.assertEqual(normal["rates"][1]["receiver_divergence_review"]["status"], "NO_DIVERGENCE_OBSERVED")
        self.assertEqual(divergent["rates"][1]["receiver_divergence_review"]["status"], "REVIEW_REQUIRED")

    def test_invalid_or_drifting_reference_cannot_support_review(self):
        for kwargs in ({"invalid": True}, {"drift": True}):
            with self.subTest(kwargs=kwargs):
                result = self.analyze(receiver=120, **kwargs)
                self.assertTrue(all(rate["receiver_divergence_review"]["status"] == "NOT_EVALUATED"
                                    for rate in result["rates"]))


if __name__ == "__main__":
    unittest.main()

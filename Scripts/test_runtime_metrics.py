import subprocess
import unittest
from unittest import mock

from Scripts.runtime_metrics import parse_process_metrics, process_metrics


class RuntimeMetricsParsingTests(unittest.TestCase):
    def test_parses_cpu_percent_and_darwin_rss_kib(self):
        cpu_percent, rss_mib = parse_process_metrics("  1.25   4096\n")
        self.assertEqual(cpu_percent, 1.25)
        self.assertEqual(rss_mib, 4.0)

    def test_rejects_malformed_nonfinite_and_negative_values(self):
        for output in ("", "1", "1 2 3", "nan 42", "inf 42", "-1 42", "1 -42", "bad 42"):
            with self.subTest(output=output), self.assertRaises(ValueError):
                parse_process_metrics(output)

    def test_rejects_nonfinite_converted_memory(self):
        with self.assertRaises(ValueError):
            parse_process_metrics("1 " + "9" * 400)


class RuntimeMetricsLocaleTests(unittest.TestCase):
    def test_runs_ps_in_c_locale_so_decimal_comma_locales_parse(self):
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="68.8 4096\n", stderr="")
        with mock.patch.dict("os.environ", {"LC_ALL": "fr_FR.UTF-8", "LANG": "fr_FR.UTF-8"}), \
                mock.patch("Scripts.runtime_metrics.subprocess.run", return_value=completed) as run:
            self.assertEqual(process_metrics(123), (68.8, 4.0))
        environment = run.call_args.kwargs["env"]
        self.assertEqual(environment["LC_ALL"], "C")
        self.assertEqual(environment["LANG"], "C")

    def test_rejects_decimal_comma_instead_of_guessing_locale(self):
        with self.assertRaises(ValueError):
            parse_process_metrics("68,8 4096")


if __name__ == "__main__":
    unittest.main()

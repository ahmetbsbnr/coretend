#!/usr/bin/env python3
"""Checks the capture plan and contact sheet of Scripts/capture_screens.py without a display."""

import unittest

try:
    from . import capture_screens as kit
except ImportError:
    import capture_screens as kit


class CapturePlanTests(unittest.TestCase):
    def test_every_surface_is_planned_in_both_languages_and_appearances(self):
        planned = {(name, language, appearance) for name, _, _, _, language, appearance in kit.shots()}
        surfaces = kit.DESTINATIONS + [extra[0] for extra in kit.EXTRAS]
        self.assertEqual(len(surfaces), 11)
        self.assertEqual(planned, {(s, l, a) for s in surfaces for l in ("fr", "en") for a in ("light", "dark")})
        self.assertEqual(len(kit.shots()), len(planned), "a surface is planned twice")

    def test_destinations_match_the_app(self):
        with open("Sources/AppShell/Destination.swift", encoding="utf-8") as stream:
            source = stream.read()
        declared = source.split("case ", 1)[1].split("\n", 1)[0]
        self.assertEqual(sorted(kit.DESTINATIONS), sorted(part.strip() for part in declared.split(",")))

    def test_contact_sheet_shows_captures_and_names_every_gap(self):
        results = {(s, l, a): "ok" for s, _, _, _, l, a in kit.shots()}
        results[("settings", "en", "dark")] = "keystroke refused (Accessibility permission?)"
        del results[("palette", "fr", "light")]
        page = kit.contact_sheet(results, "2026-09-27 21:00")
        self.assertIn('src="overview-fr-light.png"', page)
        self.assertNotIn('src="settings-en-dark.png"', page)
        self.assertIn("keystroke refused (Accessibility permission?)", page)
        self.assertIn(">not run<", page)
        self.assertEqual(page.count("<img "), len(results) - 1)


if __name__ == "__main__":
    unittest.main()

import unittest
import sys

sys.dont_write_bytecode = True
import check_architecture


def package_fixture():
    return {
        "toolsVersion": {"_version": "6.0.0"},
        "platforms": [{"platformName": "macos", "version": "14.0"}],
        "dependencies": [],
        "targets": [
            {"name": "SafetyCore", "dependencies": []},
            {"name": "ScanCore", "dependencies": [{"byName": ["ProductContract", None]}]},
            {"name": "Domain", "dependencies": [
                {"byName": ["SafetyCore", None]},
                {"byName": ["Persistence", None]},
            ]},
        ],
    }


class ArchitectureContractTests(unittest.TestCase):
    def test_accepts_declared_swift6_macos14_modular_package(self):
        self.assertEqual(check_architecture.validate(package_fixture()), [])

    def test_rejects_external_package_dependency(self):
        package = package_fixture()
        package["dependencies"].append({"sourceControl": [{"url": "https://example.invalid/pkg"}]})
        self.assertIn("external SwiftPM dependencies are not allowed", check_architecture.validate(package))

    def test_rejects_macos_below_supported_minimum(self):
        package = package_fixture()
        package["platforms"][0]["version"] = "13.0"
        self.assertIn("macOS deployment target must be at least 14.0", check_architecture.validate(package))

    def test_design_rules_reject_generic_styling_outside_design_system(self):
        bad = {
            "Sources/CoreTendApp/A.swift": "Button {} label: { Text(\"x\") }.buttonStyle(.plain)\n"
                                             ".foregroundStyle(Color.blue)\n"
                                             "let c = Color(red: 0.1, green: 0.2, blue: 0.3)\n"
                                             ".foregroundStyle(.orange)\n"
                                             "withAnimation(.linear.repeatForever()) {}\n",
        }
        errors = check_architecture.design_violations(bad)
        self.assertEqual(len(errors), 5, errors)
        self.assertTrue(errors[0].startswith("Sources/CoreTendApp/A.swift:1:"))

    def test_design_rules_allow_the_design_system_palette_and_comments(self):
        fine = {
            "Sources/DesignSystem/Palette.swift": "Color(red: 1, green: 1, blue: 1)\n.buttonStyle(.plain)\n",
            "Sources/CoreTendApp/B.swift": "// .buttonStyle(.plain) is forbidden\n"
                                            ".foregroundStyle(Palette.accent.color)\n"
                                            "case .red: break\n"
                                            "RGB(red: 0.1, green: 0.2, blue: 0.3)\n",
        }
        self.assertEqual(check_architecture.design_violations(fine), [])

    def test_destructive_confirmation_needs_a_safe_return_default(self):
        risky = {"Sources/CoreTendApp/C.swift": '.confirmationDialog("Move?", isPresented: $p) {\n'
                                                 'Button("Move", role: .destructive) {}\nButton("Cancel", role: .cancel) {}\n}\n'
                                                 'Button("Remove row", role: .destructive) {}\n'}
        self.assertEqual(len(check_architecture.trash_dialog_violations(risky)), 1)
        safe = {"Sources/CoreTendApp/C.swift": '.alert("Clear?", isPresented: $p) {\nButton("Clear", role: .destructive) {}\n'
                                                'Button("Cancel", role: .cancel) {}.keyboardShortcut(.defaultAction)\n}\n'}
        self.assertEqual(check_architecture.trash_dialog_violations(safe), [])

    def test_rejects_write_capable_dependencies_in_scancore(self):
        package = package_fixture()
        package["targets"][1]["dependencies"].append({"byName": ["SafetyCore", None]})
        self.assertIn("ScanCore may not depend on SafetyCore or Persistence", check_architecture.validate(package))

    def test_rejects_transitive_write_capable_dependencies_in_scancore(self):
        package = package_fixture()
        package["targets"][1]["dependencies"].append({"byName": ["ScanAdapter", None]})
        package["targets"].append({"name": "ScanAdapter", "dependencies": [{"byTarget": ["Persistence", None]}]})
        self.assertIn("ScanCore may not depend on SafetyCore or Persistence", check_architecture.validate(package))


if __name__ == "__main__":
    unittest.main()

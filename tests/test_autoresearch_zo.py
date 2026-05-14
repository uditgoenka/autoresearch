from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "zo" / "skills" / "autoresearch" / "scripts" / "autoresearch_cli.py"
spec = importlib.util.spec_from_file_location("autoresearch_zo_cli", SCRIPT_PATH)
assert spec is not None and spec.loader is not None
zo_cli = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = zo_cli
spec.loader.exec_module(zo_cli)


class AutoresearchZoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spec = zo_cli.load_spec()

    def test_slash_colon_subcommand_is_detected(self) -> None:
        command_key, tokens = zo_cli.detect_command_and_tokens(
            ["/autoresearch:debug", "--scope", "src/**/*.ts", "--symptom", "API returns 500"],
            self.spec,
        )
        self.assertEqual(command_key, "debug")
        self.assertEqual(tokens, ["--scope", "src/**/*.ts", "--symptom", "API returns 500"])

    def test_plain_space_subcommand_is_detected(self) -> None:
        command_key, tokens = zo_cli.detect_command_and_tokens(
            ["autoresearch", "plan", "Goal:", "improve", "docs"],
            self.spec,
        )
        self.assertEqual(command_key, "plan")
        self.assertEqual(tokens, ["Goal:", "improve", "docs"])

    def test_embedded_invocation_preserves_context_as_prose(self) -> None:
        command_key, tokens = zo_cli.detect_command_and_tokens(
            ["Please run /autoresearch:security --diff on the changed auth files"],
            self.spec,
        )
        parsed = zo_cli.parse_command_tokens(command_key, tokens, self.spec)
        self.assertEqual(command_key, "security")
        self.assertEqual(parsed.normalized_tokens, ["--diff"])
        self.assertEqual(parsed.prose, "Please run on the changed auth files")

    def test_prompt_points_to_zo_skill(self) -> None:
        parsed = zo_cli.parse_command_tokens("plan", ["Goal:", "improve", "docs"], self.spec)
        prompt = zo_cli.build_prompt(parsed)
        self.assertIn("Skills/autoresearch/SKILL.md", prompt)
        self.assertIn("autoresearch:plan", prompt)
        self.assertIn("Goal: improve docs", prompt)


if __name__ == "__main__":
    unittest.main()

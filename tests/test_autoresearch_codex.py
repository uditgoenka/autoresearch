from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1] / "plugins" / "autoresearch" / "scripts"
sys.path.insert(0, str(SCRIPT_DIR))

from autoresearch_cli import build_prompt, detect_command_and_tokens, load_spec, parse_command_tokens  # noqa: E402


class AutoresearchCodexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spec = load_spec()

    def test_root_command_defaults_when_first_token_is_not_command(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["Goal:", "Increase", "coverage"],
            self.spec
        )
        self.assertEqual(command_key, "autoresearch")
        self.assertEqual(tokens, ["Goal:", "Increase", "coverage"])

    def test_prefixed_subcommand_is_detected(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["autoresearch:security", "--diff", "--fail-on", "critical"],
            self.spec
        )
        self.assertEqual(command_key, "security")
        self.assertEqual(tokens, ["--diff", "--fail-on", "critical"])

    def test_codex_dollar_colon_subcommand_is_detected(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["$autoresearch:debug", "--fix", "--scope", "src/**/*.ts"],
            self.spec
        )
        self.assertEqual(command_key, "debug")
        self.assertEqual(tokens, ["--fix", "--scope", "src/**/*.ts"])

    def test_codex_dollar_space_subcommand_is_detected(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["$autoresearch", "fix", "--from-debug"],
            self.spec
        )
        self.assertEqual(command_key, "fix")
        self.assertEqual(tokens, ["--from-debug"])

    def test_codex_quoted_dollar_space_subcommand_is_detected(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["$autoresearch reason --iterations 20"],
            self.spec
        )
        self.assertEqual(command_key, "reason")
        self.assertEqual(tokens, ["--iterations", "20"])

    def test_codex_embedded_dollar_space_subcommand_is_detected(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["Also run $autoresearch reason --iterations 20 for more options"],
            self.spec
        )
        self.assertEqual(command_key, "reason")
        self.assertEqual(tokens, ["Also", "run", "--iterations", "20", "for", "more", "options"])

    def test_claude_slash_subcommand_is_detected_for_compatibility(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["/autoresearch:probe", "--chain", "plan,autoresearch"],
            self.spec
        )
        self.assertEqual(command_key, "probe")
        self.assertEqual(tokens, ["--chain", "plan,autoresearch"])

    def test_plain_space_subcommand_is_detected(self) -> None:
        command_key, tokens = detect_command_and_tokens(
            ["autoresearch", "debug", "--symptom", "API returns 500"],
            self.spec
        )
        self.assertEqual(command_key, "debug")
        self.assertEqual(tokens, ["--symptom", "API returns 500"])

    def test_debug_chain_flag_is_supported(self) -> None:
        parsed = parse_command_tokens(
            "debug",
            ["--chain", "fix", "--scope", "src/**/*.ts", "--symptom", "API returns 500"],
            self.spec
        )
        self.assertEqual(
            parsed.normalized_tokens,
            ["--chain", "fix", "--scope", "src/**/*.ts", "--symptom", "API returns 500"]
        )
        self.assertEqual(parsed.flag_values["--chain"], ["fix"])

    def test_flag_parsing_keeps_prose_context(self) -> None:
        parsed = parse_command_tokens(
            "predict",
            ["--scope", "src/**/*.ts", "--chain", "debug,fix", "focus", "authentication"],
            self.spec
        )
        self.assertEqual(parsed.normalized_tokens, ["--scope", "src/**/*.ts", "--chain", "debug,fix"])
        self.assertEqual(parsed.prose, "focus authentication")

    def test_invalid_flag_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "Unsupported flag"):
            parse_command_tokens("ship", ["--unknown"], self.spec)

    def test_prompt_rendering_preserves_command_and_extra_text(self) -> None:
        parsed = parse_command_tokens("security", ["--diff", "--fix"], self.spec)
        prompt = build_prompt(parsed, "Iterations: 15\nScope: src/api/**/*.ts")
        self.assertIn("autoresearch:security --diff --fix", prompt)
        self.assertIn("Iterations: 15", prompt)
        self.assertIn("Scope: src/api/**/*.ts", prompt)


if __name__ == "__main__":
    unittest.main()

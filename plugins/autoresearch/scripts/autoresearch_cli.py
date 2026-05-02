#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence, Tuple


PLUGIN_ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = PLUGIN_ROOT / "resources" / "autoresearch-command-spec.json"
INVOCATION_PREFIXES = ("$", "/")


class ParseError(ValueError):
    pass


@dataclass
class ParsedInvocation:
    command_key: str
    invocation: str
    normalized_tokens: List[str]
    prose: str
    flag_values: Dict[str, List[object]]


def load_spec() -> Dict[str, object]:
    with SPEC_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def normalize_invocation_token(raw: str) -> str:
    token = raw.strip()
    while token.startswith(INVOCATION_PREFIXES):
        token = token[1:]
    if token.startswith("autoresearch_"):
        token = "autoresearch:" + token.split("_", 1)[1]
    return token


def normalize_command_name(raw: str, spec: Dict[str, object]) -> str:
    commands = spec["commands"]
    raw = normalize_invocation_token(raw)
    if raw == "autoresearch":
        return "autoresearch"
    if raw.startswith("autoresearch:"):
        key = raw.split(":", 1)[1]
        if key in commands:
            return key
    if raw in commands and raw != "autoresearch":
        return raw
    raise ParseError(f"Unknown autoresearch command: {raw}")


def expand_raw_tokens(raw_tokens: Sequence[str]) -> List[str]:
    expanded: List[str] = []
    for token in raw_tokens:
        if not any(marker in token for marker in ("autoresearch", "$autoresearch", "/autoresearch")):
            expanded.append(token)
            continue
        try:
            split_tokens = shlex.split(token)
        except ValueError:
            split_tokens = [token]
        expanded.extend(split_tokens or [token])
    return expanded


def detect_command_and_tokens(raw_tokens: Sequence[str], spec: Dict[str, object]) -> Tuple[str, List[str]]:
    tokens = expand_raw_tokens(raw_tokens)
    if not tokens:
        return "autoresearch", []

    command_index = 0
    command_key = "autoresearch"
    found_command = False
    for index, token in enumerate(tokens):
        try:
            command_key = normalize_command_name(token, spec)
        except ParseError:
            continue
        command_index = index
        found_command = True
        break

    if not found_command:
        return "autoresearch", tokens

    first = tokens[command_index]
    try:
        command_key = normalize_command_name(first, spec)
    except ParseError:
        return "autoresearch", tokens

    preamble = tokens[:command_index]
    remainder = tokens[command_index + 1 :]
    if command_key == "autoresearch":
        if remainder:
            try:
                next_key = normalize_command_name(remainder[0], spec)
            except ParseError:
                next_key = "autoresearch"
            if next_key != "autoresearch":
                return next_key, preamble + remainder[1:]
        return "autoresearch", preamble + remainder
    return command_key, preamble + remainder


def parse_command_tokens(command_key: str, tokens: Sequence[str], spec: Dict[str, object]) -> ParsedInvocation:
    command_spec = spec["commands"][command_key]
    flag_defs = {flag["name"]: flag for flag in command_spec["flags"]}
    normalized_tokens: List[str] = []
    prose_parts: List[str] = []
    flag_values: Dict[str, List[object]] = {}

    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            prose_parts.extend(tokens[index + 1 :])
            break

        if token.startswith("--"):
            name, has_equals, inline_value = token.partition("=")
            flag = flag_defs.get(name)
            if flag is None:
                raise ParseError(f"Unsupported flag for {command_spec['label']}: {name}")

            takes_value = bool(flag["takes_value"])
            if takes_value:
                if has_equals:
                    value = inline_value
                else:
                    index += 1
                    if index >= len(tokens):
                        raise ParseError(f"Flag {name} requires a value")
                    value = tokens[index]
                flag_values.setdefault(name, []).append(value)
                normalized_tokens.extend([name, value])
            else:
                if has_equals:
                    raise ParseError(f"Flag {name} does not accept a value")
                flag_values.setdefault(name, []).append(True)
                normalized_tokens.append(name)
        else:
            prose_parts.append(token)
        index += 1

    invocation = command_spec["label"]
    return ParsedInvocation(
        command_key=command_key,
        invocation=invocation,
        normalized_tokens=normalized_tokens,
        prose=" ".join(prose_parts).strip(),
        flag_values=flag_values
    )


def build_prompt(parsed: ParsedInvocation, extra_text: str = "") -> str:
    command_line = parsed.invocation
    if parsed.normalized_tokens:
        command_line = f"{command_line} {' '.join(parsed.normalized_tokens)}"

    sections = [
        "Use the installed `autoresearch` Codex skill. Treat the next line as the canonical command invocation.",
        "",
        command_line
    ]

    if parsed.prose:
        sections.extend(["", parsed.prose])

    extra = extra_text.strip()
    if extra:
        sections.extend(["", extra])

    return "\n".join(sections).rstrip() + "\n"


def read_extra_text(input_file: str | None) -> str:
    parts: List[str] = []
    if input_file:
        parts.append(Path(input_file).read_text(encoding="utf-8").strip())
    if not sys.stdin.isatty():
        stdin_text = sys.stdin.read().strip()
        if stdin_text:
            parts.append(stdin_text)
    return "\n\n".join(part for part in parts if part)


def build_codex_command(args: argparse.Namespace, prompt: str) -> List[str]:
    cmd = ["codex"]
    if args.interactive:
        pass
    else:
        cmd.append("exec")

    if args.cd:
        cmd.extend(["-C", args.cd])
    if args.model:
        cmd.extend(["-m", args.model])
    if args.profile:
        cmd.extend(["-p", args.profile])
    if args.sandbox:
        cmd.extend(["-s", args.sandbox])
    if args.skip_git_repo_check and not args.interactive:
        cmd.append("--skip-git-repo-check")
    if args.json and not args.interactive:
        cmd.append("--json")
    if args.output_last_message and not args.interactive:
        cmd.extend(["-o", args.output_last_message])

    cmd.append(prompt)
    return cmd


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Codex wrapper for Autoresearch. Preserves the existing autoresearch command grammar."
    )
    parser.add_argument("--interactive", action="store_true", help="Launch `codex` instead of `codex exec`.")
    parser.add_argument("--print-prompt", action="store_true", help="Print the generated prompt before execution.")
    parser.add_argument("--no-exec", action="store_true", help="Do not invoke Codex; print the prompt and exit.")
    parser.add_argument("--cd", help="Working directory to pass to Codex.")
    parser.add_argument("--model", help="Model name to pass through to Codex.")
    parser.add_argument("--profile", help="Codex profile name.")
    parser.add_argument("--sandbox", help="Codex sandbox mode.")
    parser.add_argument("--skip-git-repo-check", action="store_true", help="Forward to `codex exec`.")
    parser.add_argument("--json", action="store_true", help="Emit JSONL events from `codex exec`.")
    parser.add_argument("--output-last-message", help="Write the last Codex message to a file.")
    parser.add_argument("--input-file", help="Append config or context from a file to the generated prompt.")
    parser.add_argument("--list-commands", action="store_true", help="List supported autoresearch commands and exit.")
    parser.add_argument("remainder", nargs=argparse.REMAINDER, help="Autoresearch command and flags.")
    return parser


def list_commands(spec: Dict[str, object]) -> int:
    for key, command in spec["commands"].items():
        print(f"{command['label']}: {command['description']}")
        if key == "autoresearch":
            continue
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = create_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    spec = load_spec()

    if args.list_commands:
        return list_commands(spec)

    raw_tokens = args.remainder
    if raw_tokens and raw_tokens[0] == "--":
        raw_tokens = raw_tokens[1:]

    try:
        command_key, command_tokens = detect_command_and_tokens(raw_tokens, spec)
        parsed = parse_command_tokens(command_key, command_tokens, spec)
    except ParseError as exc:
        parser.exit(2, f"autoresearch: {exc}\n")
    extra_text = read_extra_text(args.input_file)
    prompt = build_prompt(parsed, extra_text)

    if args.print_prompt or args.no_exec:
        sys.stdout.write(prompt)
        if args.no_exec:
            return 0

    command = build_codex_command(args, prompt)
    completed = subprocess.run(command, check=False)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())

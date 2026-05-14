#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence, Tuple


SKILL_ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = SKILL_ROOT / "resources" / "autoresearch-command-spec.json"
INVOCATION_PREFIXES = ("$", "/")
DEFAULT_MODEL = "openai:gpt-5.5-2026-04-23"


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
        if "autoresearch" not in token:
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

    preamble = tokens[:command_index]
    remainder = tokens[command_index + 1:]
    if command_key == "autoresearch" and remainder:
        try:
            next_key = normalize_command_name(remainder[0], spec)
        except ParseError:
            next_key = "autoresearch"
        if next_key != "autoresearch":
            return next_key, preamble + remainder[1:]
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
            prose_parts.extend(tokens[index + 1:])
            break
        if token.startswith("--"):
            name, has_equals, inline_value = token.partition("=")
            flag = flag_defs.get(name)
            if flag is None:
                raise ParseError(f"Unsupported flag for {command_spec['label']}: {name}")
            if flag["takes_value"]:
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

    return ParsedInvocation(
        command_key=command_key,
        invocation=command_spec["label"],
        normalized_tokens=normalized_tokens,
        prose=" ".join(prose_parts).strip(),
        flag_values=flag_values,
    )


def build_prompt(parsed: ParsedInvocation, extra_text: str = "") -> str:
    command_line = parsed.invocation
    if parsed.normalized_tokens:
        command_line = f"{command_line} {' '.join(parsed.normalized_tokens)}"

    sections = [
        "Use the installed Zo Computer `autoresearch` skill from `Skills/autoresearch/SKILL.md`.",
        "Treat the next line as the canonical command invocation.",
        "",
        command_line,
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


def call_zo(prompt: str, model_name: str) -> int:
    token = os.environ.get("ZO_CLIENT_IDENTITY_TOKEN")
    if not token:
        print("ZO_CLIENT_IDENTITY_TOKEN is not set. Re-run inside Zo Computer or use --no-exec to print the prompt.", file=sys.stderr)
        return 2

    payload = json.dumps({"input": prompt, "model_name": model_name}).encode("utf-8")
    request = urllib.request.Request(
        "https://api.zo.computer/zo/ask",
        data=payload,
        headers={"authorization": token, "content-type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=None) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        print(exc.read().decode("utf-8", errors="replace"), file=sys.stderr)
        return 1

    output = data.get("output", data)
    if isinstance(output, str):
        print(output)
    else:
        print(json.dumps(output, indent=2))
    return 0


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Zo Computer wrapper for Autoresearch chat invocations.")
    parser.add_argument("--print-prompt", action="store_true", help="Print the generated prompt before execution.")
    parser.add_argument("--no-exec", action="store_true", help="Do not call the Zo API; print the prompt and exit.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Zo model name (default: {DEFAULT_MODEL}).")
    parser.add_argument("--input-file", help="Append config or context from a file to the generated prompt.")
    parser.add_argument("--list-commands", action="store_true", help="List supported autoresearch commands and exit.")
    parser.add_argument("remainder", nargs=argparse.REMAINDER, help="Autoresearch command and flags.")
    return parser


def list_commands(spec: Dict[str, object]) -> int:
    for command in spec["commands"].values():
        print(f"{command['label']}: {command['description']}")
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

    prompt = build_prompt(parsed, read_extra_text(args.input_file))
    if args.print_prompt or args.no_exec:
        sys.stdout.write(prompt)
        if args.no_exec:
            return 0
    return call_zo(prompt, args.model)


if __name__ == "__main__":
    raise SystemExit(main())

"""Prompt filtering utilities.

Blocks prompts containing disallowed terms (case-insensitive) using simple
ASCII word-boundary matching. Intended as a lightweight safety/UX guardrail.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable, Optional, Sequence


DEFAULT_BLOCKED_PROMPT_TERMS: Sequence[str] = (
    "nude",
    "naked",
    "topless",
    "nsfw",
    "deepfake",
    "fake",
)


@dataclass(frozen=True)
class PromptFilterConfig:
    enabled: bool = True
    blocked_terms: Sequence[str] = DEFAULT_BLOCKED_PROMPT_TERMS


def _compile_blocked_term_patterns(blocked_terms: Iterable[str]) -> list[re.Pattern[str]]:
    patterns: list[re.Pattern[str]] = []
    for raw_term in blocked_terms:
        term = (raw_term or "").strip().lower()
        if not term:
            continue

        # ASCII-ish word boundary: letters/digits only are considered part of a word.
        # This catches punctuation and hyphenation like "topless," or "top-less".
        pattern = re.compile(rf"(?i)(?:^|[^a-z0-9]){re.escape(term)}(?:$|[^a-z0-9])")
        patterns.append(pattern)
    return patterns


def find_blocked_terms(text: Optional[str], blocked_terms: Iterable[str]) -> list[str]:
    if not text:
        return []

    haystack = text.strip()
    if not haystack:
        return []

    matches: set[str] = set()
    for raw_term in blocked_terms:
        term = (raw_term or "").strip().lower()
        if not term:
            continue
        if re.search(rf"(?i)(?:^|[^a-z0-9]){re.escape(term)}(?:$|[^a-z0-9])", haystack):
            matches.add(term)

    return sorted(matches)


def validate_prompt_fields(
    instruction: str,
    system_prompt: Optional[str],
    config: PromptFilterConfig,
) -> list[str]:
    """Return list of blocked terms found across provided fields."""
    if not config.enabled:
        return []

    blocked_terms = config.blocked_terms or []
    found: set[str] = set()

    for term in find_blocked_terms(instruction, blocked_terms):
        found.add(term)
    for term in find_blocked_terms(system_prompt, blocked_terms):
        found.add(term)

    return sorted(found)

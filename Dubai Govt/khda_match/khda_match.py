"""Match Digii values to KHDA master-list codes (khda_sync.master_value).

Standalone module for the khda_sync service: standard library only, Python 3.9+.

Lookup order, first hit wins:

    1. confirmed  digii_code_map row for the tenant (kind = list name, khda_code set) whose code exists in the list
    2. alias      extra value -> code pairs supplied by the caller (synonyms such as "Unmarried" -> "S")
    3. exact      value equals a label or code, ignoring case, accents and surrounding whitespace
    4. normalized value equals a label or code after keeping only letters and digits
                  ("Engineering" = "Engineering.", "Full-Time" = "Full time")
    5. prefix     one normalized string starts with the other, the shorter is at least `prefix_min_ratio` of the
                  longer and exactly one entry qualifies ("Indian" -> "India"; "american" is NOT taken as
                  "American Samoa" because the overlap is too short)
    6. fuzzy      difflib similarity of the normalized strings >= `fuzzy_threshold` and ahead of the runner-up
                  by `fuzzy_margin` (typos such as "Morocco" -> "Morrocco"); never an entry contained in the value
                  or the other way round ("Unmarried" is not "Married")

Steps 1-4 are reliable (`Match.auto_accept` is True). Steps 5-6 are guesses: store them as suggested_code with
`Match.score` as suggestion_score and let a person confirm them, rather than sending them to KHDA directly.

Example:

    matcher = KhdaMatcher(master_values, confirmed)
    m = matcher.match("country", "Indian", tenant_id="689")
    m.code, m.method, m.score            # ('IN', 'prefix', 0.833...)
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

__all__ = ["Match", "KhdaMatcher", "normalize", "fold", "load_master_values", "load_confirmed"]

RELIABLE_METHODS = frozenset({"confirmed", "alias", "exact", "normalized"})
_NON_ALNUM = re.compile(r"[^0-9a-z]+")


def fold(value: Optional[str]) -> str:
    """Case-, accent- and whitespace-insensitive form, e.g. '  Marrïed ' -> 'married'."""
    if value is None:
        return ""
    text = unicodedata.normalize("NFKD", str(value))
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return " ".join(text.casefold().split())


def normalize(value: Optional[str]) -> str:
    """Letters and digits only, e.g. 'Full-Time' -> 'fulltime', 'Engineering.' -> 'engineering'."""
    return _NON_ALNUM.sub("", fold(value))


@dataclass(frozen=True)
class Match:
    """Result of a lookup. `code` is None when nothing matched; `candidates` lists ties / near misses."""

    code: Optional[str]
    label: Optional[str] = None
    method: Optional[str] = None
    score: float = 0.0
    candidates: Tuple[Tuple[str, str, float], ...] = field(default_factory=tuple)

    @property
    def auto_accept(self) -> bool:
        """True when the match is reliable enough to use without review."""
        return self.method in RELIABLE_METHODS

    def __bool__(self) -> bool:
        return self.code is not None


@dataclass(frozen=True)
class _Entry:
    code: str
    label: str
    folded_label: str
    folded_code: str
    norm_label: str
    norm_code: str


class KhdaMatcher:
    """Matches Digii values against the KHDA code lists.

    master_values: {list_name: [(code, label), ...]} - rows of khda_sync.master_value.
    confirmed:     {(tenant_id, kind, digii_id): khda_code} - confirmed rows of khda_sync.digii_code_map
                   (digii_id is compared case-, accent- and whitespace-insensitively).
    aliases:       {list_name: {digii_value: code}} - optional synonyms that no string rule can find.
    """

    def __init__(
        self,
        master_values: Mapping[str, Iterable[Tuple[str, Optional[str]]]],
        confirmed: Optional[Mapping[Tuple[str, str, str], str]] = None,
        aliases: Optional[Mapping[str, Mapping[str, str]]] = None,
        *,
        prefix_min_ratio: float = 0.75,
        prefix_min_length: int = 4,
        fuzzy_threshold: float = 0.88,
        fuzzy_margin: float = 0.05,
    ) -> None:
        self.prefix_min_ratio = prefix_min_ratio
        self.prefix_min_length = prefix_min_length
        self.fuzzy_threshold = fuzzy_threshold
        self.fuzzy_margin = fuzzy_margin

        self._lists: Dict[str, List[_Entry]] = {}
        self._codes: Dict[str, Dict[str, _Entry]] = {}
        for list_name, rows in master_values.items():
            entries = []
            for code, label in rows:
                if code is None or str(code).strip() == "":
                    continue
                code = str(code).strip()
                label = (label or "").strip()
                entries.append(_Entry(code, label, fold(label), fold(code), normalize(label), normalize(code)))
            self._lists[list_name] = entries
            self._codes[list_name] = {e.code: e for e in entries}

        self._confirmed: Dict[Tuple[str, str, str], str] = {}
        for (tenant_id, kind, digii_id), code in (confirmed or {}).items():
            if code is not None and str(code).strip():
                self._confirmed[(str(tenant_id), kind, fold(digii_id))] = str(code).strip()

        self._aliases: Dict[str, Dict[str, str]] = {
            list_name: {fold(value): str(code).strip() for value, code in pairs.items()}
            for list_name, pairs in (aliases or {}).items()
        }

    # ------------------------------------------------------------------ public API

    def match(
        self,
        list_name: str,
        value: Optional[str],
        *,
        tenant_id: Optional[str] = None,
        kind: Optional[str] = None,
        fuzzy: bool = True,
        fuzzy_threshold: Optional[float] = None,
        prefix_min_ratio: Optional[float] = None,
    ) -> Match:
        """Return the KHDA code for `value` in `list_name`.

        kind:  digii_code_map kind to look up confirmed mappings under; defaults to `list_name`. Use it for
               mappings keyed by something other than the value, e.g. kind="degree" with value=programme_types.id.
        fuzzy: False stops after the reliable steps (confirmed / alias / exact / normalized).
        fuzzy_threshold / prefix_min_ratio: override the matcher-wide values for this lookup.
        """
        if list_name not in self._lists:
            raise KeyError(f"unknown KHDA list {list_name!r}")
        if value is None or str(value).strip() == "":
            return Match(None)

        hit = self._confirmed_match(list_name, value, tenant_id, kind or list_name)
        if hit:
            return hit
        hit = self._alias_match(list_name, value)
        if hit:
            return hit
        if kind is not None and kind != list_name:
            return Match(None)          # value is a key (e.g. an id), not text: no string matching

        hit = self._exact_match(list_name, value) or self._normalized_match(list_name, value)
        if hit or not fuzzy:
            return hit or Match(None)
        return (self._prefix_match(list_name, value, prefix_min_ratio)
                or self._fuzzy_match(list_name, value, fuzzy_threshold))

    def code(self, list_name: str, value: Optional[str], default: Optional[str] = None, **kwargs) -> Optional[str]:
        """Code only, `default` when nothing matched - mirrors COALESCE(lookup, default) in the reports."""
        return self.match(list_name, value, **kwargs).code or default

    def lists(self) -> Sequence[str]:
        return tuple(self._lists)

    # ------------------------------------------------------------------ steps

    def _entry(self, list_name: str, code: str) -> Optional[_Entry]:
        return self._codes[list_name].get(code)

    def _confirmed_match(self, list_name, value, tenant_id, kind) -> Optional[Match]:
        if tenant_id is None:
            return None
        code = self._confirmed.get((str(tenant_id), kind, fold(value)))
        entry = self._entry(list_name, code) if code else None
        return Match(entry.code, entry.label, "confirmed", 1.0) if entry else None

    def _alias_match(self, list_name, value) -> Optional[Match]:
        code = self._aliases.get(list_name, {}).get(fold(value))
        entry = self._entry(list_name, code) if code else None
        return Match(entry.code, entry.label, "alias", 1.0) if entry else None

    def _exact_match(self, list_name, value) -> Optional[Match]:
        folded = fold(value)
        for e in self._lists[list_name]:
            if folded in (e.folded_label, e.folded_code):
                return Match(e.code, e.label, "exact", 1.0)
        return None

    def _normalized_match(self, list_name, value) -> Optional[Match]:
        norm = normalize(value)
        if not norm:
            return None
        hits = [e for e in self._lists[list_name] if norm in (e.norm_label, e.norm_code)]
        if len(hits) == 1:
            return Match(hits[0].code, hits[0].label, "normalized", 1.0)
        if len(hits) > 1:               # e.g. two labels that differ only in punctuation: ambiguous
            return Match(None, candidates=tuple((e.code, e.label, 1.0) for e in hits))
        return None

    def _prefix_match(self, list_name, value, min_ratio=None) -> Optional[Match]:
        min_ratio = self.prefix_min_ratio if min_ratio is None else min_ratio
        norm = normalize(value)
        if len(norm) < self.prefix_min_length:
            return None
        hits = []
        for e in self._lists[list_name]:
            label = e.norm_label
            if not label:
                continue
            shorter, longer = sorted((norm, label), key=len)
            if longer.startswith(shorter):
                ratio = len(shorter) / len(longer)
                if ratio >= min_ratio:
                    hits.append((e, ratio))
        if len(hits) == 1:
            e, ratio = hits[0]
            return Match(e.code, e.label, "prefix", ratio)
        if len(hits) > 1:
            return Match(None, candidates=tuple((e.code, e.label, r) for e, r in hits))
        return None

    def _fuzzy_match(self, list_name, value, threshold=None) -> Match:
        threshold = self.fuzzy_threshold if threshold is None else threshold
        norm = normalize(value)
        if len(norm) < self.prefix_min_length:
            return Match(None)
        scored = []
        for e in self._lists[list_name]:
            if not e.norm_label:
                continue
            # one string inside the other is not a typo ('unmarried' contains 'married'): the prefix step judges
            # those, fuzzy must not accept them
            if e.norm_label in norm or norm in e.norm_label:
                continue
            scored.append((SequenceMatcher(None, norm, e.norm_label).ratio(), e))
        scored.sort(key=lambda s: s[0], reverse=True)
        top = tuple((e.code, e.label, round(s, 4)) for s, e in scored[:3])
        if not scored:
            return Match(None)
        best_score, best = scored[0]
        runner_up = scored[1][0] if len(scored) > 1 else 0.0
        if best_score >= threshold and best_score - runner_up >= self.fuzzy_margin:
            return Match(best.code, best.label, "fuzzy", best_score, top)
        return Match(None, candidates=top)


# ---------------------------------------------------------------------- loaders (any DB-API cursor, e.g. pymysql)

def load_master_values(cursor, list_names: Optional[Iterable[str]] = None, env: Optional[str] = None
                       ) -> Dict[str, List[Tuple[str, Optional[str]]]]:
    """Read khda_sync.master_value into {list_name: [(code, label), ...]}."""
    sql = "SELECT list_name, code, label FROM khda_sync.master_value WHERE 1 = 1"
    params: List[str] = []
    if env is not None:
        sql += " AND env = %s"
        params.append(env)
    names = list(list_names) if list_names is not None else None
    if names:
        sql += " AND list_name IN (" + ", ".join(["%s"] * len(names)) + ")"
        params.extend(names)
    cursor.execute(sql, params)
    out: Dict[str, List[Tuple[str, Optional[str]]]] = {}
    for list_name, code, label in cursor.fetchall():
        out.setdefault(list_name, []).append((code, label))
    return out


def load_confirmed(cursor, tenant_id: Optional[str] = None) -> Dict[Tuple[str, str, str], str]:
    """Read confirmed khda_sync.digii_code_map rows into {(tenant_id, kind, digii_id): khda_code}."""
    sql = "SELECT tenant_id, kind, digii_id, khda_code FROM khda_sync.digii_code_map WHERE khda_code IS NOT NULL"
    params: List[str] = []
    if tenant_id is not None:
        sql += " AND tenant_id = %s"
        params.append(str(tenant_id))
    cursor.execute(sql, params)
    return {(str(t), k, d): c for t, k, d, c in cursor.fetchall()}

"""Apply KHDA codes (with fuzzy matching) to the output of a Dubai Govt report query.

The report queries return plain Digii values in the coded columns (e.g. 'Indian', 'Undergraduate'). For each
value this script uses the confirmed mapping, else exact / normalised / prefix / fuzzy matching (khda_match),
else the column default, and writes:

    <output>        the report data with KHDA codes
    review sheet    each Digii value that was guessed or not matched, with the closest KHDA entries - confirm them
                    into khda_sync.digii_code_map so they map exactly next time
                    (sheet "Review" for .xlsx, <output>_review.csv for .csv)

Inputs are files (.csv or .xlsx), no database connection:
    query data           the report query's export
    KHDA lists           SELECT list_name, code, label FROM khda_sync.master_value
    confirmed mappings   SELECT kind, digii_id, digii_label, khda_code FROM khda_sync.digii_code_map
                         WHERE tenant_id = '<KHDA tenant, e.g. 689>' AND khda_code IS NOT NULL      (optional)

Usage: set the paths below and run `python apply_khda_codes.py`, or override them on the command line:
    python apply_khda_codes.py enrollment.csv enrollment_khda.csv --master master_value.csv --confirmed digii_code_map.csv
    python apply_khda_codes.py graduates.xlsx out.xlsx --master master_value.csv --strict     # no guesses
The report is detected from the input's columns; --report graduates (or REPORT below) forces it.
--offline uses the unit-test sample lists instead of the KHDA files (for trying the script only).
"""

from __future__ import annotations

import argparse
import csv
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

from khda_match import KhdaMatcher, Match, fold

# ---------------------------------------------------------------------- settings
REPORT         = None                                                   # None = detect from the columns, or a REPORTS key
INPUT_PATH     = r"C:\Users\suraj\OneDrive\Desktop\query_output.csv"    # query export (.csv / .xlsx)
MASTER_PATH    = r"C:\Users\suraj\OneDrive\Desktop\master_value.csv"    # khda_sync.master_value: list_name, code, label
CONFIRMED_PATH = r"C:\Users\suraj\OneDrive\Desktop\digii_code_map.csv"  # confirmed digii_code_map rows of one tenant
                                                                        #   (kind, digii_id, digii_label, khda_code); None = none
OUTPUT_PATH    = r"C:\Users\suraj\OneDrive\Desktop\report_khda.csv"     # result (.csv / .xlsx)
STRICT         = False                                                  # True: do not apply prefix / fuzzy guesses

# digii_code_map kinds whose KHDA list has another name. 'degree' rows are keyed by programme_types.id, which the
# queries do not return, so they are matched by digii_label (the programme type name) instead.
KIND_TO_LIST = {"degree": "degreeorprogramlevel", "specialisation": "areaofspecialization"}
_TENANT = "_"                                # the confirmed export holds one tenant

# Coded columns per report (headers = the query's column aliases). Each column:
#   "list"             KHDA list name
#   "default"          code when nothing matched
#   "blank"            code when the cell is empty (default: same as "default")
#   "fuzzy"            False = exact / normalised matching only
#   "fuzzy_threshold"  minimum similarity for a fuzzy (typo) match, default 0.88
#   "prefix_min_ratio" minimum overlap for a prefix match ('Indian' -> India = 0.83), default 0.75
#   "aliases"          {Digii value: code} synonyms for this column
#   "other_column"     column that keeps the Digii value when no code is found
_NATIONALITY = {"list": "country", "default": "UN", "blank": "NS", "fuzzy_threshold": 0.70}
REPORTS = {
    "applicants_basic_details": {
        "columns": {
            "Degrees / Program Levels": {"list": "degreeorprogramlevel", "default": "UD"},
            "Area of Specialization":   {"list": "areaofspecialization", "default": "99"},
        },
        # the query returns one row per Digii value; rows that end up with the same codes are summed
        "aggregate": {
            "keys": ["Institution Code", "Institution Name", "Academic Period",
                     "Degrees / Program Levels", "Area of Specialization"],
            "sum":  ["Number of Applicants", "Number of Admissions Offered", "Number of New Enrollments"],
            "max":  ["Last Updated"],
        },
    },
    "employee_basic_details": {
        "columns": {
            "Nationality":       _NATIONALITY,
            "Campus":            {"list": "campus", "default": None},
            "Qualification":     {"list": "degreeorprogramlevel", "default": "UD"},
            "Position Title":    {"list": "staffposition", "default": "OTH", "other_column": "Position Title Other"},
            "Employment Status": {"list": "employmentstatus", "default": "OT"},
        },
    },
    "employee_workload": {
        "columns": {
            # the query falls back to A / B / D (faculty full-time / part-time / administrator) when no category is set
            "Employee Category": {"list": "facultycategory", "default": "A"},
            "Full or Part Time": {"list": "fullparttime", "default": "FT"},
            "Employee position": {"list": "staffposition", "default": "OTH"},
        },
    },
    "institute_employers": {
        "columns": {
            # Digii industry / company type, e.g. 'IT Industry', 'NGO'; unmatched -> 19 (OTHER)
            "Industry":         {"list": "employmentindustry", "default": "19", "blank": None},
            # Sector / Location_* are not captured yet (the query returns NULL); coded once they are
            "Sector":           {"list": "employmentsector", "default": None},
            "Location_Country": {"list": "country", "default": None},
            "Location_Emirate": {"list": "emirates", "default": None},
        },
    },
    "graduates": {
        "columns": {
            "Marital Status Code": {"list": "maritalstatus", "default": "U"},
            "Nationality":         _NATIONALITY,
            "Graduate Degree":     {"list": "degreeorprogramlevel", "default": "UD"},
        },
    },
    "student_attrition": {
        "columns": {
            "Nationality":                _NATIONALITY,
            "Student Level (Level Code)": {"list": "studentlevel", "default": None},
            "Attrition Category":         {"list": "leavercategory", "default": None},
        },
    },
    "student_enrollment": {
        "columns": {
            "Marital Status":                         {"list": "maritalstatus", "default": "U"},
            "Nationality":                            _NATIONALITY,
            "Student Degree (Degree Code)":           {"list": "degreeorprogramlevel", "default": "UD"},
            "Employment Status":                      {"list": "studemploymentstatus", "default": None},
            "Employment Sector":                      {"list": "employmentsector", "default": None},
            # the query returns IELTS / TOEFL; the TOEFL variant (CBT / IBT / paper) is not captured -> OTHER
            "Language Test Proficiency Exam":         {"list": "acadproficiencytest", "default": "30", "blank": None,
                                                       "aliases": {"IELTS": "11"}},
            "High School System":                     {"list": "highschoolsystem", "default": "OT", "blank": None},
            # the query turns the year of passing YYYY into the academic year code (YYYY-1)YY; kept if in the list
            "High School Completion Year":            {"list": "academicyear", "default": None, "fuzzy": False},
            "12th Grade stream (Stream Code)":        {"list": "12thgradestream", "default": "NA"},
            "Last Completed Higher Education Degree": {"list": "degreeorprogramlevel", "default": "UD", "blank": None},
            "Last Completed Higher Education Year":   {"list": "academicyear", "default": None, "fuzzy": False},
        },
    },
    "student_internship": {
        "columns": {
            "Internship Industry":         {"list": "employmentindustry", "default": None},
            "Internship Sector":           {"list": "employmentsector", "default": None},
            "National/Out/Country/Online": _NATIONALITY,
        },
    },
    "student_scholarship": {
        "columns": {
            "Scholarship Type":          {"list": "scholarshiptype", "default": "OT"},
            "Scholarship Provider Type": {"list": "scprovidertype", "default": "OT"},
            "Nationality":               _NATIONALITY,
        },
    },
    "education_background": {
        "columns": {
            "High School Country":                      _NATIONALITY,
            "Last Higher Education Institution Country": _NATIONALITY,
            "Employee Qualification Country":           _NATIONALITY,
        },
    },
    "person_profile": {
        "columns": {
            "Nationality":           _NATIONALITY,
            "Nationality of Mother": _NATIONALITY,
        },
    },
}

REVIEW_HEADER = ["Column", "Digii value", "Rows", "Code applied", "Method", "Score", "Closest KHDA entries"]
GUESS_METHODS = ("prefix", "fuzzy")


# ---------------------------------------------------------------------- helpers

def _text(value) -> str:
    """The cell as trimmed text; '' for empty / NULL cells."""
    text = "" if value is None else str(value).strip()
    return "" if text.upper() == "NULL" else text


def _by_lower(header) -> dict:
    """{lower-case header: actual header}, for case-insensitive column lookups."""
    return {h.strip().lower(): h for h in header}


def _is_excel(path: Path) -> bool:
    return path.suffix.lower() in (".xlsx", ".xlsm")


# ---------------------------------------------------------------------- reading / writing

def read_table(path: Path):
    """(header, rows as dicts) from a .csv or .xlsx file (first sheet)."""
    if _is_excel(path):
        from openpyxl import load_workbook
        wb = load_workbook(path, read_only=True, data_only=True)
        try:
            rows = wb.worksheets[0].iter_rows(values_only=True)
            header = [str(h) if h is not None else "" for h in next(rows)]
            return header, [dict(zip(header, r)) for r in rows if any(v is not None for v in r)]
        finally:
            wb.close()
    with path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        return list(reader.fieldnames or []), [dict(r) for r in reader]


def write_table(path: Path, header, rows, review):
    """Write the data and the review list; returns the review file for .csv (None for .xlsx: sheet 'Review')."""
    data = [[r.get(h) for h in header] for r in rows]
    if _is_excel(path):
        from openpyxl import Workbook
        wb = Workbook()
        for ws, head, body in ((wb.active, header, data), (wb.create_sheet("Review"), REVIEW_HEADER, review)):
            ws.append(head)
            for r in body:
                ws.append(r)
        wb.active.title = "Data"
        wb.save(path)
        return None
    review_path = path.with_name(path.stem + "_review.csv")
    for target, head, body in ((path, header, data), (review_path, REVIEW_HEADER, review)):
        with target.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(head)
            w.writerows(body)
    return review_path


# ---------------------------------------------------------------------- matching

def resolve(matcher: KhdaMatcher, spec: dict, value, strict: bool):
    """(KHDA code, Match) for one cell."""
    text = _text(value)
    if not text:
        return spec.get("blank", spec["default"]), Match(None, method="blank")

    m = matcher.match(spec["list"], text, tenant_id=_TENANT, fuzzy=spec.get("fuzzy", True),
                      fuzzy_threshold=spec.get("fuzzy_threshold"), prefix_min_ratio=spec.get("prefix_min_ratio"))
    alias = {fold(k): v for k, v in spec.get("aliases", {}).items()}.get(fold(text))
    if alias is not None and (not m.code or m.method in GUESS_METHODS):     # column synonyms beat guesses
        m = Match(alias, method="alias", score=1.0)

    if m.code and (m.auto_accept or not strict):
        return m.code, m
    return spec["default"], m


def apply_codes(report: str, header, rows, matcher: KhdaMatcher, strict: bool = False):
    """Replace the coded columns of `rows` with KHDA codes; returns (rows, review list)."""
    config = REPORTS[report]
    by_lower = _by_lower(header)
    columns = {}                                         # actual header -> spec
    for name, spec in config["columns"].items():
        actual = by_lower.get(name.lower())
        if actual is None:
            print(f"warning: column {name!r} not in the input, skipped", file=sys.stderr)
        elif spec["list"] not in matcher.lists():
            print(f"warning: KHDA list {spec['list']!r} not loaded, column {name!r} left as is", file=sys.stderr)
        else:
            columns[actual] = spec

    cache, review = {}, {}                               # (column, value) -> (code, Match) / review row
    for row in rows:
        for col, spec in columns.items():
            raw = row.get(col)
            key = (col, _text(raw))
            if key not in cache:
                cache[key] = resolve(matcher, spec, raw, strict)
            code, m = cache[key]
            row[col] = code

            other_col = by_lower.get(spec.get("other_column", "").lower())
            if other_col:
                if m.code and code == m.code:            # coded: nothing to put in "other"
                    row[other_col] = None
                elif not row.get(other_col):
                    row[other_col] = raw if key[1] else None

            if m.method != "blank" and not m.auto_accept:       # guessed or unmatched -> review
                if key not in review:
                    near = "; ".join(f"{c} = {l} ({s:.2f})" for c, l, s in m.candidates)
                    review[key] = [col, key[1], 0, code, m.method or "no match",
                                   round(m.score, 3) if m.code else None, near]
                review[key][2] += 1

    if "aggregate" in config:
        rows = aggregate(rows, config["aggregate"], by_lower)
    return rows, list(review.values())


def detect_report(header) -> str:
    """The report with all its coded columns in the input, else the one with the most of them."""
    present = set(_by_lower(header))
    scores = {name: sum(c.lower() in present for c in cfg["columns"]) for name, cfg in REPORTS.items()}
    full = [name for name, cfg in REPORTS.items() if scores[name] == len(cfg["columns"])]
    best = max(scores.values())
    candidates = full or [name for name, s in scores.items() if s == best and s > 0]
    if len(candidates) == 1:
        return candidates[0]
    sys.exit("could not tell which report this is" + (f" (could be: {', '.join(sorted(candidates))})" if candidates else "")
             + " - set REPORT at the top of this script")


def _number(value) -> Decimal:
    try:
        return Decimal(_text(value) or 0)
    except InvalidOperation:
        return Decimal(0)


def aggregate(rows, spec: dict, by_lower: dict):
    """Merge rows with the same key columns: sum the "sum" columns, keep the latest "max" value."""
    def cols(names):
        return [by_lower.get(n.lower(), n) for n in names]

    keys, sums, maxes = cols(spec["keys"]), cols(spec.get("sum", [])), cols(spec.get("max", []))
    groups = {}
    for row in rows:
        k = tuple(row.get(c) for c in keys)
        if k not in groups:
            groups[k] = {**row, **{s: Decimal(0) for s in sums}}
        g = groups[k]
        for s in sums:
            g[s] += _number(row.get(s))
        for m in maxes:
            if _text(row.get(m)) and (not _text(g.get(m)) or str(row.get(m)) > str(g.get(m))):
                g[m] = row.get(m)
    for g in groups.values():
        for s in sums:
            g[s] = int(g[s]) if g[s] == g[s].to_integral_value() else float(g[s])
    return list(groups.values())


# ---------------------------------------------------------------------- KHDA lists

def _read_export(path: Path, required: set, setting: str):
    if not path.is_file():
        sys.exit(f"file not found: {path}  (set {setting} at the top of this script)")
    header, rows = read_table(path)
    cols = _by_lower(header)
    if not required <= set(cols):
        sys.exit(f"{path} needs the columns {', '.join(sorted(required))} (found: {', '.join(header)})")
    return cols, rows


def load_master_values_file(path: Path) -> dict:
    """{list_name: [(code, label), ...]} from an export of: SELECT list_name, code, label FROM khda_sync.master_value"""
    cols, rows = _read_export(path, {"list_name", "code", "label"}, "MASTER_PATH")
    master_values = {}
    for r in rows:
        name, code = _text(r.get(cols["list_name"])), _text(r.get(cols["code"]))
        if name and code:
            master_values.setdefault(name, []).append((code, r.get(cols["label"])))
    if not master_values:
        sys.exit(f"{path} has no KHDA list rows")
    return master_values


def load_confirmed_file(path: Path) -> dict:
    """{(tenant, list, Digii value): code} from an export of: SELECT kind, digii_id, digii_label, khda_code
    FROM khda_sync.digii_code_map WHERE tenant_id = ... AND khda_code IS NOT NULL.
    Each row matches on its digii_id and on its digii_label."""
    cols, rows = _read_export(path, {"kind", "digii_id", "khda_code"}, "CONFIRMED_PATH")
    if "tenant_id" in cols:
        tenants = {_text(r.get(cols["tenant_id"])) for r in rows} - {""}
        if len(tenants) > 1:
            sys.exit(f"{path} has several tenants ({', '.join(sorted(tenants))}): export one tenant only")
    value_cols = [cols[c] for c in ("digii_id", "digii_label") if c in cols]
    confirmed = {}
    for r in rows:
        kind, code = _text(r.get(cols["kind"])), _text(r.get(cols["khda_code"]))
        if not kind or not code:
            continue
        list_name = KIND_TO_LIST.get(kind, kind)
        for c in value_cols:
            value = _text(r.get(c))
            if value:
                confirmed.setdefault((_TENANT, list_name, value), code)
    return confirmed


def main() -> None:
    p = argparse.ArgumentParser(description="Apply KHDA codes (fuzzy matching) to exported report data")
    p.add_argument("input", nargs="?", type=Path, default=Path(INPUT_PATH), help="query output (.csv / .xlsx)")
    p.add_argument("output", nargs="?", type=Path, default=Path(OUTPUT_PATH), help="result file (.csv / .xlsx)")
    p.add_argument("--report", default=REPORT, choices=sorted(REPORTS), help="default: detected from the columns")
    p.add_argument("--master", type=Path, default=Path(MASTER_PATH), help="khda_sync.master_value export")
    p.add_argument("--confirmed", type=Path, default=Path(CONFIRMED_PATH) if CONFIRMED_PATH else None,
                   help="confirmed khda_sync.digii_code_map export")
    p.add_argument("--strict", action="store_true", default=STRICT, help="do not apply prefix / fuzzy guesses")
    p.add_argument("--offline", action="store_true", help="unit-test sample lists instead of --master")
    args = p.parse_args()
    if not args.input.is_file():
        sys.exit(f"input file not found: {args.input}  (set INPUT_PATH at the top of this script)")

    # if args.offline:
    #     from test_khda_match import MASTER_VALUES
    #     matcher = KhdaMatcher(MASTER_VALUES)
    else:
        master_values = load_master_values_file(args.master)
        confirmed = load_confirmed_file(args.confirmed) if args.confirmed else {}
        matcher = KhdaMatcher(master_values, confirmed)
        print(f"{sum(map(len, master_values.values()))} KHDA list entries, {len(confirmed)} confirmed mappings")

    header, rows = read_table(args.input)
    report = args.report or detect_report(header)
    print(f"report: {report}" + ("" if args.report else " (detected from the columns)"))
    rows, review = apply_codes(report, header, rows, matcher, strict=args.strict)
    review_path = write_table(args.output, header, rows, review)

    guessed = sum(1 for r in review if r[4] in GUESS_METHODS)
    print(f"{len(rows)} rows written to {args.output}")
    print(f"{len(review)} values to review ({guessed} guessed, {len(review) - guessed} not matched)"
          + (f" -> {review_path}" if review_path else " -> sheet 'Review'"))


if __name__ == "__main__":
    main()

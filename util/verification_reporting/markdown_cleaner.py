# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Apply filters to strings, while tracking the accumulated changes in files
that can be diff-reviewed. The filters are currently tailored to catch markdown
bugs.

A MarkdownCleaner object maps filter functions to regex patterns. After calling
MarkdownCleaner.clean on a given string, each filter in FILTER_MAP is applied in
the order defined on matches found by the corresponding regex pattern.

The input string transformed independently by each filter as well as the final
string with all filters applied is stored to be written as a scratch file at a later time.
"""

import re
from typing import NamedTuple
from pathlib import Path
import subprocess

REPO_TOP = Path(__file__).resolve().parents[2]
REPO_DIRS = []
for p in REPO_TOP.iterdir():
    if not p.is_dir() or p.name.startswith("."):
        continue
    REPO_DIRS.append(p.name)

bullet = r"(?:[-*+]|(?:\d+\.))"
bullet = rf"{bullet}(?!{bullet})"
bullet_end_condition = rf"(?:\n[ ]*{bullet})|(?:\n[ ]*\n)"

# Patterns producing matches consumed by the corresponding filter in FILTER_MAP
PATTERNS = {"incorrect_bullet": rf"(?sm)^[ ]*{bullet}(\S+?) ",
            "bullet_paragraph": rf"(?sm)^[ ]*{bullet} (.+?)\n[ ]*\n",
            "bullet_section": rf"(?sm)^(([ ]*{bullet} )[^\n]*)((?:(?!{bullet_end_condition}).)*)",
            "md_link": r"\[[^\]]+\]\(([^\)]+)\)"}


class Replacement(NamedTuple):
    replace: bool
    replacement: str
    insert_index: int
    continue_index: int = -1


class MarkdownCleaner:
    FILTER_MAP = {"format_desc_whitespace": None,
                  "normalize_desc_whitespace": None,
                  "add_space_to_bullet": PATTERNS["incorrect_bullet"],
                  "properly_end_bulleted_paragraph": PATTERNS["bullet_section"],
                  "properly_start_bulleted_paragraph": PATTERNS["bullet_paragraph"],
                  "fix_links": PATTERNS["md_link"]}

    def __init__(self, filters: str | list[str], new_desc_path: Path = None):
        if filters == "all":
            filters = [filter_fn_name for filter_fn_name in self.FILTER_MAP]
        assert isinstance(filters, list), "Please provide a list of filters, even if it is singular"
        for filter in filters:
            try:
                getattr(self, filter)
            except AttributeError:
                raise AttributeError(f"Filter name '{filter}' must map to a defined function")
        self.filters = filters
        self.filtered_descripts = {filter: [] for filter in ["original"] + self.filters + ["all"]}
        self.curr_match = None
        self.new_desc_path = new_desc_path
        self.filtered_dir = Path(__file__).resolve().parent / "scratch/filtered_descripts"
        self.filtered_dir.mkdir(parents=True, exist_ok=True)

    def replace_matches(self, desc: str, filter_fn: str) -> str:
        """Collects all replacements returned by calling the function
        pointed to by filter_fn on the matches provided by the corresponding
        regex pattern. Returns a new description with these replacements applied.
        """

        filtered_desc = ""
        replacements = []
        filter_patt = self.FILTER_MAP[filter_fn]
        filter_fn = getattr(self, filter_fn)

        if filter_patt:
            for match in re.finditer(filter_patt, desc):
                self.curr_match = match
                r = filter_fn(desc)
                if r.continue_index == -1:
                    r = r._replace(continue_index=match.end(0))
                replacements.append(r)
        else:
            replacements = [filter_fn(desc)]

        i = 0
        for r in replacements:
            filtered_desc += desc[i:r.insert_index]
            if r.replace:
                filtered_desc += r.replacement
            i = r.continue_index
        filtered_desc += desc[i:]
        return filtered_desc

    def clean(self, desc: str, desc_id="No description ID") -> str:
        """Applies and saves descriptions independently filtered from the original.
        A final description filtered by all filters in the order defined at
        initialization is saved and returned.
        """

        desc_id = f"# {desc_id}\n"
        self.filtered_descripts["original"].append(desc_id + desc)
        final_desc = desc
        for filter in self.filters:
            filtered_desc = self.replace_matches(desc, filter)
            self.filtered_descripts[filter].append(desc_id + filtered_desc)
            final_desc = self.replace_matches(final_desc, filter)
        self.filtered_descripts["all"].append(desc_id + final_desc)
        return final_desc

    def write_filtered_descripts(self):
        """Stores files of all the descriptions the MarkdownCleaner
        has thus far cleaned (one for each filter pass) so they can be
        diff-ed and reviewed for correctness"""

        for filter in ["original", "all"] + self.filters:
            if filter == "original":
                file_header = "Original markdown descriptions\n"
            elif filter == "all":
                file_header = "All filters applied\n"
            else:
                file_header = f"Filtered by {filter}\n"
            desc_list = [""] + self.filtered_descripts[filter]
            desc_glob = file_header + "\n<----->\n".join(desc_list)
            file_name = self.filtered_dir / f"{filter}.md"
            file_name.write_text(desc_glob, encoding="utf-8")

    def diff_view_filtered_descripts(self, f1="original", f2="all"):
        cmd = ["code", "--diff"]
        files = [self.filtered_dir / f"{f}.md" for f in [f1, f2]]
        for file in files:
            if not file.exists():
                raise FileNotFoundError(f"Cannot view description diff: {file} does not exist.\n"
                                        "Try running 'write_filtered_descripts' to generate it")
        cmd += [str(f) for f in files]
        subprocess.run(cmd)

    # Filter functions #

    # Ensure every bullet is formatted correctly (with a space)
    def add_space_to_bullet(self, desc: str) -> Replacement:
        incorrect_bullet = self.curr_match
        return Replacement(True, " " + incorrect_bullet.group(1) + " ", incorrect_bullet.start(1))

    # Ensure every bulleted paragraph is preceeded by a full blank line
    def properly_start_bulleted_paragraph(self, desc: str) -> Replacement:
        bulleted_paragraph = self.curr_match
        if desc[bulleted_paragraph.start(0) - 2:bulleted_paragraph.start(0)] != "\n\n":
            correct_bullet_section = "\n" + bulleted_paragraph.group(0)
            return Replacement(True, correct_bullet_section, bulleted_paragraph.start(0))
        return Replacement(False, None, bulleted_paragraph.end(0))

    # Ensure bullet pargraph ends with a full blank line
    def properly_end_bulleted_paragraph(self, desc: str) -> Replacement:
        bullet_section = self.curr_match
        reference_indent = len(bullet_section.group(2))
        trailing_sections = bullet_section.group(3)
        new_bullet = bullet_section.group(1) + "\n"
        if trailing_sections:
            for line in trailing_sections.split("\n"):
                if line == "":
                    continue
                match = re.search(r"^([ ]*)(\S?)", line)
                indent = len(match.group(1))
                if indent == reference_indent:
                    new_bullet += line + "\n"
                else:
                    new_bullet += "\n" + line + "\n"
                    reference_indent = indent
            return Replacement(True, new_bullet[:-1], bullet_section.start(0))
        return Replacement(False, None, bullet_section.end(0))

    # Ensure all links are rooted in the correct place, given that the description location changes
    def fix_links(self, desc: str) -> Replacement:
        if self.new_desc_path:
            md_link = self.curr_match
            link = md_link.group(1)
            first_link_segment = link[:link.find("/")]
            if first_link_segment in REPO_DIRS:
                hops_to_repo_base = len(self.new_desc_path.relative_to(REPO_TOP).parts)
                hops_to_repo_base = hops_to_repo_base * "../"
                # mdbook turns README.md links into index.html
                correct_link = str(hops_to_repo_base + f"{link}").replace("README.md", "")
                return Replacement(True, correct_link + ")", md_link.start(1))
        return Replacement(False, None, self.curr_match.end(0))

    # Ensure there is no extra whitespace to the left of a description (maintaining relative tabs)
    def normalize_desc_whitespace(self, desc: str) -> Replacement:
        continue_index = len(desc)

        # If the desc begins with text, do not allow it to dictate the relative indent of the
        # entire description; Remove it and re-algin at the end.
        first_line = None
        desc = desc.split("\n")
        if desc[0] != "":
            first_line = desc[0]
            desc = desc[1:]
        desc = "\n".join(desc)

        # Find the smallest indent
        whitespace_patt = r"(?m)^( *)(\S?.*)$"
        smallest_indent = None
        for match in re.finditer(whitespace_patt, desc):
            indent = len(match.group(1))
            if match.group(0) != "":
                if smallest_indent is None:
                    smallest_indent = indent
                else:
                    smallest_indent = min(smallest_indent, indent)
        if smallest_indent is None:
            smallest_indent = 0

        # If the first line was removed, re-align it with the relative indent of the description
        if first_line:
            desc = f"{smallest_indent * ' '}{first_line}\n{desc}"

        # Normalize relative to this smallest indent
        def normalize_indent(match):
            indent = len(match.group(1))
            new_indent = indent - smallest_indent if indent else 0
            return new_indent * " " + match.group(2)
        desc = re.sub(whitespace_patt, normalize_indent, desc)
        return Replacement(True, desc, 0, continue_index)

    # Ensure all whitespace (except newlines) are spaces, and that descriptions end with two \n
    # Ensure there are no lines with only spaces
    def format_desc_whitespace(self, desc: str) -> Replacement:
        continue_index = len(desc)
        desc = re.sub(r"[^\S\n]", " ", desc)
        desc = re.sub(r"(?<=\S)[ \n]*\Z", "\n\n", desc)
        desc = re.sub(r"(?m)^( +)$", "", desc)
        return Replacement(True, desc, 0, continue_index)


md_cleaner = MarkdownCleaner("all")

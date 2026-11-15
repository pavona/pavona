#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
from pathlib import Path
import re
from textwrap import indent
import logging as logger
from verification_reporting.markdown_cleaner import md_cleaner
from topgen import lib as lib
from verification_reporting import md_report_templates as tmpl
from mako.template import Template
from typing import NamedTuple, Any


REPO_TOP = Path(__file__).resolve().parents[1]
TOPS = lib.get_all_top_names(REPO_TOP)


class ReportInfo(NamedTuple):
    report_path: Path
    spec: str | None
    features: list[dict[str, Any]]
    tests: list[dict[str, Any]]
    testpoints: list[dict[str, Any]]
    readme_tpl_data: dict[str, Any]


def name_to_mdbook_ref(name: str) -> str:
    """Returns an anchor id mdbook expects, meaning all letters and digits
    are lowercased, '-' and '_' are kept, whitespace becomes '-' and
    many whitespaces together are not merged. Everything else gets dropped"""

    ref = ""
    for c in name:
        if not (c.isalnum() or c in ['-', '_'] or c.isspace()):
            continue
        if c.isspace():
            c = '-'
        else:
            c = c.lower()
        ref += c
    return ref


def data_entry(is_mapped: bool, ref: str | None = None) -> str:
    entry = ""
    if is_mapped:
        if ref is None:
            entry = "X"
        else:
            entry = tmpl.REF_TMPL.format(ref=ref, name="X")
    return tmpl.DATA_ENTRY_TMPL.format(is_mapped=entry)


def row_entry(row: str, data_entries_html: str, ref: str | None = None) -> str:
    if ref:
        row_name = tmpl.REF_TMPL.format(ref=ref, name=row)
    else:
        row_name = row
    return tmpl.ROW_AND_DATA_TMPL.format(row_name=row_name, data_entries=data_entries_html)


def mapping_to_matrix(rows: list[str], cols: list[str], mapping: dict[str, set[str]],
                      row_title: str, col_title: str, base_ref: str | None = None) -> str | None:
    """Returns an html matrix representing the boolean mapping provided, with an "X" placed in
    those cells marked as True in the mapping. Each row optionally carries a reference to the
    row name from any base_ref provided. Marked cells are linked as well.

    If no mapping exists (i.e. all intersections between rows and columns are False),
    or if rows/cols are empty, returns None
    """
    if not rows or not cols or not mapping:
        return None

    col_names_html = []
    for col in cols:
        col_names_html.append(tmpl.COL_NAME_TMPL.format(col_name=col))
    col_names_html = "\n".join(col_names_html)

    rows_and_data_html = ""
    rows_html = []

    no_mapping = True
    for row in rows:
        data_entries_html = []
        ref = f"{base_ref}{name_to_mdbook_ref(row)}" if base_ref else None
        for col in cols:
            is_mapped = col in mapping[row]
            if is_mapped:
                no_mapping = False
            data_entries_html.append(indent(data_entry(is_mapped, ref=ref), 2 * " "))

        data_entries_html = "\n".join(data_entries_html)
        row_html = row_entry(row, data_entries_html, ref=ref)
        rows_html.append(row_html)

    if no_mapping:
        return None

    rows_and_data_html = []
    for row_html in rows_html:
        rows_and_data_html.append(row_html)
    rows_and_data_html = "\n".join(rows_and_data_html)

    col_names_html = indent(col_names_html, 4 * " ")
    rows_and_data_html = indent(rows_and_data_html, 2 * " ")
    return tmpl.MATRIX_TMPL.format(col_names=col_names_html, rows_and_data=rows_and_data_html,
                                   row_title=row_title, col_title=col_title)


def parse_ip_spec(ip: str, spec: str | None) -> tuple[dict[str, set[str]], list[str]]:
    """Given a theory of operation spec, returns the sections and a mapping
    from features to section name.
    """

    sections = []
    active_features = set()

    are_features_mapped = dict()
    sections_to_features = dict()

    if spec is None:
        return sections_to_features, sections

    for i, line in enumerate(spec.split("\n")):
        if not line:
            continue

        m = re.search(r'<!-- BEGIN-FEATURE: (.+?) -->', line)
        if m:
            feature = m.group(1)
            assert feature not in active_features, (f"IP {ip} feature {feature} "
                                                    f"BEGIN-tag at line {i + 1} is repeated")
            are_features_mapped[feature] = False
            active_features.add(feature)
            continue

        m = re.search(r'<!-- END-FEATURE: (.+?) -->', line)
        if m:
            feature = m.group(1)
            assert feature in active_features, (f"IP {ip} feature {feature} "
                                                f"END-tag at line {i + 1} does not have a "
                                                "corresponding BEGIN tag")
            active_features.remove(feature)
            assert are_features_mapped[feature], (f"IP {ip} feature {feature} "
                                                  f"END-tag at line {i + 1} does enclose a section")
            continue

        if line.startswith("#"):
            section = re.search(r'(#+)\s+(.+)$', line).group(2)
            assert section not in sections, f"{ip} spec section repeated: {section}"
            sections.append(section)
            sections_to_features[section] = active_features.copy()
            for feature in active_features:
                are_features_mapped[feature] = True

    return sections_to_features, sections


def load_verification_report_info(ip: str, top: str | None = None) -> ReportInfo:
    """Figures out where the report is going to be saved, and loads the
    relevant information (features, testpoints, tests, and specification).

    If the top passed in remains None, the IP is assumed to be top-agnostic,
    and testpoints will include chip testpoints from all tops.

    testpoint paths are returned to aid the creation of the report README.
    """

    readme_tpl_data = {"tp_path": None, "chip_tp_paths": dict(), "fpv_tp_path": None,
                       "has_spec": True, "has_testpoints": True, "has_features": True,
                       "has_tests": True, "all_tp_paths": []}
    # Derive report path
    if top:
        top_cfg = lib.get_top_cfg(top, REPO_TOP)
        ip_hjson_path = lib.get_ip_hjson_path(ip, top_cfg, REPO_TOP)
    else:
        ip_hjson_path = lib.get_top_agnostic_ip_hjson_path(ip, REPO_TOP)
    ip_doc_dir = ip_hjson_path.parents[1] / "doc"
    if not ip_doc_dir.exists():
        raise FileNotFoundError(f"Expected doc directory for IP {ip} at {ip_doc_dir}")
    if not (ip_doc_dir / "theory_of_operation.md").exists():
        warning_msg = f"No specification available for {ip}"
        if top:
            warning_msg += f" in the context of top {top}"
        logger.warning(warning_msg)
        readme_tpl_data["has_spec"] = False
    ip_report_path = ip_doc_dir / "verification_report"
    ip_report_path.mkdir(parents=True, exist_ok=True)

    # Grab the IP's hjson
    ip_hjson = lib.load_cfg(ip_hjson_path)
    if ip_hjson.get("features") is None:
        raise ValueError(f"IP {ip} doesn't have a feature attribute")
    features_di = {f["name"]: f | {"testpoints": set(), "tests": set()}
                   for f in ip_hjson["features"]}
    testpoints = []
    tests_di = dict()

    # Populate testpoints and store the paths used
    hops_to_repo_base = len(ip_report_path.relative_to(REPO_TOP).parts)
    hops_to_repo_base = hops_to_repo_base * "../"
    tp_path = ip_hjson_path.parent / f"{ip}_testplan.hjson"
    if tp_path.exists():
        testpoints += lib.load_cfg(tp_path, load_raw=True)["testpoints"]
        readme_tpl_data["tp_path"] = hops_to_repo_base + str(tp_path.relative_to(REPO_TOP))
        readme_tpl_data["all_tp_paths"].append(tp_path.relative_to(REPO_TOP))
    fpv_tp_path = tp_path.parent / f"{ip}_fpv_testplan.hjson"
    if fpv_tp_path.exists():
        testpoints += lib.load_cfg(fpv_tp_path, load_raw=True)["testpoints"]
        readme_tpl_data["fpv_tp_path"] = hops_to_repo_base + str(fpv_tp_path.relative_to(REPO_TOP))
        readme_tpl_data["all_tp_paths"].append(fpv_tp_path.relative_to(REPO_TOP))

    tops_to_parse = [top] if top else TOPS
    for top in tops_to_parse:
        chip_tp_path = REPO_TOP / f"hw/top_{top}/data/ip/chip_{ip}_testplan.hjson"
        if chip_tp_path.exists():
            chip_tps = lib.load_cfg(chip_tp_path, load_raw=True)["testpoints"]
            if not chip_tps:
                continue
            for tp in chip_tps:
                tp["name"] = tp["name"] + f" ({top})"
                tp["tests"] = [test + f" ({top})" for test in tp["tests"]]
            testpoints += chip_tps
            readme_tpl_data["chip_tp_paths"][top] = (hops_to_repo_base +
                                                     str(chip_tp_path.relative_to(REPO_TOP)))
            readme_tpl_data["all_tp_paths"].append(chip_tp_path.relative_to(REPO_TOP))

    # Synchronize the fields across features, testpoints, and test names
    for testpoint in testpoints:
        testpoint["features"] = set(testpoint["features"])
        for feature_name in testpoint["features"]:
            features_di[feature_name]["testpoints"].add(testpoint["name"])
            features_di[feature_name]["tests"].update(testpoint["tests"])

        testpoint["tests"] = set(testpoint["tests"])
        for test_name in testpoint["tests"]:
            tests_di.setdefault(test_name, {"name": test_name,
                                            "features": set(),
                                            "testpoints": set()})
            tests_di[test_name]["testpoints"].add(testpoint["name"])
            tests_di[test_name]["features"].update(testpoint["features"])

    # Collapse dicts to lists for ease of later use
    features = [features_di[feature_name] for feature_name in features_di]
    tests = [tests_di[test_name] for test_name in tests_di]

    # Load specification
    if readme_tpl_data["has_spec"]:
        spec_path = ip_hjson_path.parents[1] / "doc/theory_of_operation.md"
        spec = spec_path.read_text(encoding="utf-8")
    else:
        spec = None
    readme_tpl_data["has_features"] = len(features) > 0
    readme_tpl_data["has_testpoints"] = len(testpoints) > 0
    readme_tpl_data["has_tests"] = len(tests) > 0

    return ReportInfo(ip_report_path, spec, features, tests, testpoints, readme_tpl_data)


def populate_verification_report_data(report_data: dict[str, Any]) -> None:
    ip = report_data["ip_name"]
    features = report_data["features"]
    testpoints = report_data["testpoints"]
    tests = report_data["tests"]
    spec = report_data["spec"]

    # Create feature list table (for feature report)
    report_data["feature_list_table"] = None
    if features:
        entries = []
        for feature in sorted(features, key=lambda x: x["name"]):
            entry = tmpl.TABLE_ID_ENTRY_TMPL.format(col1_entry=feature["name"],
                                                    col2_entry=feature["desc"].replace("\n", ""),
                                                    entry_id=name_to_mdbook_ref(feature["name"]))
            entries.append(indent(entry, 4 * " "))
        entries = "\n".join(entries)
        report_data["feature_list_table"] = tmpl.TABLE_TMPL.format(col1_name="Features",
                                                                   col2_name="Descriptions",
                                                                   table_entries=entries)

    # Create feature->specification matrix (for feature report)
    feature_names = [el["name"] for el in features]
    section_to_feature_map, spec_sections = parse_ip_spec(ip, spec)
    spec_base_ref = "../theory_of_operation.md#"
    feature_spec_matrix = mapping_to_matrix(spec_sections, feature_names, section_to_feature_map,
                                            row_title="Spec Section", col_title="Features",
                                            base_ref=spec_base_ref)
    report_data["feature_spec_matrix"] = feature_spec_matrix

    # Create feature->testpoint matrix (for feature report)
    testpoint_names = [el["name"] for el in testpoints]
    testpoint_to_feature_map = dict()
    for testpoint in testpoints:
        testpoint_to_feature_map[testpoint["name"]] = testpoint["features"]
    tp_base_ref = "02_testpoint_report.md#"
    feature_testpoint_matrix = mapping_to_matrix(testpoint_names, feature_names,
                                                 testpoint_to_feature_map, row_title="Testpoints",
                                                 col_title="Features", base_ref=tp_base_ref)
    report_data["feature_testpoint_matrix"] = feature_testpoint_matrix

    # Create testpoint tables (for testpoint report)
    report_data["testpoint_report_tables"] = None
    if testpoints:
        tp_tables = []
        for testpoint in sorted(testpoints, key=lambda x: x["name"]):
            tp_features = []
            tests_html = []
            for test_name in sorted(testpoint["tests"]):
                test_ref = name_to_mdbook_ref(test_name)
                test_name = tmpl.REF_TMPL.format(ref=f"03_test_report.md#{test_ref}",
                                                 name=test_name)
                tests_html.append(test_name)
            for feature_name in sorted(testpoint["features"]):
                feature_ref = name_to_mdbook_ref(feature_name)
                feature_name = tmpl.REF_TMPL.format(ref=f"01_feature_report.md#{feature_ref}",
                                                    name=feature_name)
                tp_features.append(feature_name)
            tests_html = "<br>".join(tests_html) if tests_html else "No tests"
            features_html = "<br>".join(tp_features) if tp_features else "No features"
            tp_table_entry = tmpl.TABLE_ENTRY_TMPL.format(col1_entry=tests_html,
                                                          col2_entry=features_html)
            tp_paths = [p.name for p in report_data["readme_tpl_data"]["all_tp_paths"]]
            desc_id = f"{testpoint['name']} ({', '.join(tp_paths)})"
            formatted_desc = md_cleaner.clean(testpoint['desc'], desc_id=desc_id)
            tp_table = f"## {testpoint['name']}\n{formatted_desc}\n"
            tp_table += tmpl.TABLE_TMPL.format(col1_name="Tests",
                                               col2_name="Features",
                                               table_entries=tp_table_entry)
            tp_tables.append(tp_table)
        tp_tables = "\n\n".join(tp_tables)
        report_data["testpoint_report_tables"] = tp_tables

    # Create test tables (for test report)
    report_data["test_report_tables"] = None
    if tests:
        test_tables = []
        for test in sorted(tests, key=lambda x: x["name"]):
            test_features = []
            testpoints_html = []
            for testpoint_name in sorted(test["testpoints"]):
                testpoint_ref = name_to_mdbook_ref(testpoint_name)
                testpoint_name = tmpl.REF_TMPL.format(ref=("02_testpoint_report.md#"
                                                           f"{testpoint_ref}"),
                                                      name=testpoint_name)
                testpoints_html.append(testpoint_name)
            for feature_name in sorted(test["features"]):
                feature_ref = name_to_mdbook_ref(feature_name)
                feature_name = tmpl.REF_TMPL.format(ref=f"01_feature_report.md#{feature_ref}",
                                                    name=feature_name)
                test_features.append(feature_name)
            testpoints_html = "<br>".join(testpoints_html) if testpoints_html else "No testpoints"
            features_html = "<br>".join(test_features) if test_features else "No features"
            test_table_entry = tmpl.TABLE_ENTRY_TMPL.format(col1_entry=testpoints_html,
                                                            col2_entry=features_html)
            test_table = f"## {test['name']}\n"
            test_table += tmpl.TABLE_TMPL.format(col1_name="Testpoints",
                                                 col2_name="Features",
                                                 table_entries=test_table_entry)
            test_tables.append(test_table)
        test_tables = "\n\n".join(test_tables)
        report_data["test_report_tables"] = test_tables

    # Create unmapped tables (for unmapped report)
    def generate_unmapped_lists(source_type: str) -> None:
        target_types = ["features", "testpoints", "tests"]
        file_names = {"features": "01_feature_report.md",
                      "testpoints": "02_testpoint_report.md",
                      "tests": "03_test_report.md"}
        target_types.remove(source_type)
        for target_type in target_types:
            unmapped_sources = []
            unmapped_list = None
            for source in sorted(report_data[f"{source_type}"], key=lambda x: x["name"]):
                if not source[f"{target_type}"]:
                    source_ref = name_to_mdbook_ref(source['name'])
                    source_ref = f"{file_names[source_type]}#{source_ref}"
                    unmapped_sources.append(f"- [{source['name']}]({source_ref})")
            if unmapped_sources:
                unmapped_list = (f"The following **{source_type}** are not "
                                 f"mapped to any **{target_type}**:\n\n")
                unmapped_list += "\n".join(unmapped_sources)
            report_data[f"unmapped_{source_type}_from_{target_type}_list"] = unmapped_list
    generate_unmapped_lists("features")
    generate_unmapped_lists("testpoints")
    generate_unmapped_lists("tests")


def generate_verification_report_data(ip: str) -> tuple[dict[Path, dict[str, Any]], list[Path]]:
    """Returns a dictionary containing all the data necessary for creating a
    verification report, as well as a list of the paths the report should
    be written to.

    For top-agnostic IPs, ip_report_paths is a singular list. IP chip testpoints
    (which may differ across tops) are labeled according to the top and combined
    into the single report.

    For top-dependent IPs instantiated across more than one top (templated IPs),
    len(ip_report_paths) >= 2. In such cases, the dictionary returned is indexed
    according to the report path
    """

    report_data = dict()
    ip_report_paths = []

    tops = [None] if lib.is_ip_top_agnostic(ip, REPO_TOP) else TOPS

    for top in tops:
        report_data_i = dict()
        if top and not lib.top_has_ip(top, ip, REPO_TOP):
            continue

        report_info = load_verification_report_info(ip, top=top)
        md_cleaner.new_desc_path = report_info.report_path
        report_data_i["ip_name"] = ip
        report_data_i["features"] = report_info.features
        report_data_i["testpoints"] = report_info.testpoints
        report_data_i["tests"] = report_info.tests
        report_data_i["spec"] = report_info.spec
        full_ip_name = ip if top is None else f"{ip} ({top})"
        report_info.readme_tpl_data["full_ip_name"] = full_ip_name
        report_data_i["readme_tpl_data"] = report_info.readme_tpl_data

        populate_verification_report_data(report_data_i)
        ip_report_paths.append(report_info.report_path)
        report_data[report_info.report_path] = report_data_i

    return report_data, ip_report_paths


def write_verification_report(report_data: dict[str, Any], ip_report_path: Path) -> None:
    ip = report_data["ip_name"]

    feature_report = f"# {ip} Feature Report\n\n"
    testpoint_report = f"# {ip} Testpoint Report\n\n"
    test_report = f"# {ip} Test Report\n\n"
    unmapped_report = f"# {ip} Unmapped Elements\n\n"

    # Add feature list to feature report
    feature_report += "## Feature List\n"
    if report_data["features"]:
        feature_report += report_data["feature_list_table"]
    else:
        feature_report += f"IP {ip} currently contains no features."
    feature_report += "\n\n"

    # Add spec matrix to feature report
    feature_report += "## Feature -> Specification Matrix\n"
    if report_data["feature_spec_matrix"]:
        feature_report += report_data["feature_spec_matrix"]
    else:
        feature_report += f"IP {ip} currently contains no **Feature → Specification** mapping"
    feature_report += "\n\n"

    # Add testpoint matrix to feature report
    feature_report += "## Feature -> Testpoint Matrix\n"
    if report_data["feature_testpoint_matrix"]:
        feature_report += report_data["feature_testpoint_matrix"]
    else:
        feature_report += f"IP {ip} currently contains no **Feature → Testpoint** mapping\n"

    # Populate testpoint/test reports
    if report_data["testpoints"]:
        testpoint_report += report_data["testpoint_report_tables"]
    else:
        testpoint_report += f"IP {ip} currently contains no testpoints"
    testpoint_report += "\n"

    if report_data["tests"]:
        test_report += report_data["test_report_tables"]
    else:
        test_report += f"IP {ip} currently contains no tests"
    test_report += "\n"

    # Add unmapped features, testpoints, and tests to unmapped report
    def unmapped_report_tmpl(ip: str, report_data: dict[str, Any], source_type: str) -> str:
        target_types = ["features", "testpoints", "tests"]
        target_types.remove(source_type)
        unmapped_report = f"## Unmapped {source_type}\n\n"
        unmapped_sections = []
        if report_data[source_type]:
            for target_type in target_types:
                unmapped_section = ""
                unmapped_list = report_data[f"unmapped_{source_type}_from_{target_type}_list"]
                if unmapped_list:
                    unmapped_section += unmapped_list
                else:
                    if report_data[f"{target_type}"]:
                        unmapped_section += (f"IP {ip} **{source_type}** are fully mapped "
                                             f"to **{target_type}**.")
                    else:
                        unmapped_section += (f"IP {ip} contains no **{target_type}** for "
                                             f"**{source_type}** to map onto")
                unmapped_sections.append(unmapped_section)
            unmapped_report += "\n\n".join(unmapped_sections)
        else:
            unmapped_report += f"IP {ip} currently contains no {source_type}."
        return unmapped_report + "\n"
    unmapped_report += unmapped_report_tmpl(ip, report_data, "features")
    unmapped_report += unmapped_report_tmpl(ip, report_data, "testpoints")
    unmapped_report += unmapped_report_tmpl(ip, report_data, "tests")

    # Render template of the verification report's main page
    readme_tmpl_path = REPO_TOP / "util/verification_reporting/README.md.tpl"
    readme_tmpl = Template(filename=str(readme_tmpl_path))
    readme = readme_tmpl.render(ip_name=ip, readme_tpl_data=report_data["readme_tpl_data"])

    # Write all reports to their appropriate locations
    feature_report_file = ip_report_path / "01_feature_report.md"
    testpoint_report_file = ip_report_path / "02_testpoint_report.md"
    test_report_file = ip_report_path / "03_test_report.md"
    unmapped_report_file = ip_report_path / "04_unmapped_report.md"
    verification_report_readme = ip_report_path / "README.md"

    verification_report_readme.write_text(readme, encoding="utf-8")
    feature_report_file.write_text(feature_report, encoding="utf-8")
    testpoint_report_file.write_text(testpoint_report, encoding="utf-8")
    test_report_file.write_text(test_report, encoding="utf-8")
    unmapped_report_file.write_text(unmapped_report, encoding="utf-8")


def main(ip: str) -> None:
    # Grab feature report data (tables and matrices).
    report_data, ip_report_paths = generate_verification_report_data(ip)
    if not report_data:
        logger.warning(f"Could not generate a verification report for ip '{ip}'")
    # Write all necessary reports
    for ip_report_path in ip_report_paths:
        report_data_i = report_data[ip_report_path]
        logger.info(f"Writing verification report for IP {ip} to path "
                    f"{ip_report_path.relative_to(REPO_TOP)}")
        write_verification_report(report_data_i, ip_report_path)


def main_all() -> None:
    # Macro wrappers (as in for flash_ctrl/otp_ctrl) are ignored
    exclude_patterns = {r"(.*)macro(.*)"}
    for ip in sorted(lib.get_all_repo_ip_names(REPO_TOP, exclude=exclude_patterns)):
        main(ip)


if __name__ == "__main__":
    diff_help_msg = """After generating a report, use this flag to save files under
util/verification_reporting/scratch/filtered_descripts/{filter_name}.md. Each of these files
lists every markdown testpoint description cleaned by the corresponding filter during the
report generation process. These files can then be diff-ed to review what changes were made for
the reports generated. If vscode is installed, pass in an integer corresponding to the ith
filter to view this diff automatically. Pass in -1 to view the descriptions completely filtered.
Navigate to util/verification_reporting/README.md#description-cleaning for more information
about the filters used."""

    parser = argparse.ArgumentParser()
    parser.add_argument("ip", help="Name of ip to be reported. Run with 'all' "
                        "to generate reports for every IP in the repo")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output")
    parser.add_argument("-d", "--diff", type=int, nargs="?", const=-2, default=None,
                        help=diff_help_msg)
    args = parser.parse_args()
    logger.basicConfig(level= logger.DEBUG if args.verbose else logger.CRITICAL)
    if args.ip == "all":
        main_all()
    else:
        main(args.ip)

    if args.diff is not None:
        ith_filter = min(args.diff, len(md_cleaner.filters) - 1)
        filter_to_compare = "all" if ith_filter == -1 else md_cleaner.filters[ith_filter]
        md_cleaner.write_filtered_descripts()
        if args.diff > -2:
            md_cleaner.diff_view_filtered_descripts("original", filter_to_compare)

#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Generate HTML and dashboard summary from a merged UCIS XML database."""

from __future__ import annotations

import argparse
import html
import sys
from pathlib import Path

from ucis.report.coverage_report_builder import CoverageReportBuilder
from ucis.rgy.format_rgy import FormatRgy


def _load_ucis_xml(path: str):
    rgy = FormatRgy.inst()
    xml_desc = rgy.getDatabaseDesc("xml")
    return xml_desc.fmt_if().read(path)


def _pct(value: float) -> str:
    return f"{float(value):.2f}%"


def _bin_stats(bins) -> tuple[int, int]:
    total = len(bins)
    covered = sum(1 for b in bins if b.hit)
    return covered, total


def _render_covergroup_rows(report) -> str:
    rows = []
    for cg in sorted(report.covergroups, key=lambda item: item.name):
        cp_count = len(cg.coverpoints)
        cross_count = len(cg.crosses)
        rows.append("<tr>"
                    f"<td>{html.escape(cg.name)}</td>"
                    f"<td>{_pct(cg.coverage)}</td>"
                    f"<td>{cp_count}</td>"
                    f"<td>{cross_count}</td>"
                    "</tr>")
    return "\n".join(rows)


def _render_coverpoint_sections(report) -> str:
    sections = []
    for cg in sorted(report.covergroups, key=lambda item: item.name):
        rows = []
        for cp in sorted(cg.coverpoints, key=lambda item: item.name):
            covered, total = _bin_stats(cp.bins)
            rows.append("<tr>"
                        f"<td>{html.escape(cp.name)}</td>"
                        f"<td>{_pct(cp.coverage)}</td>"
                        f"<td>{covered}/{total}</td>"
                        f"<td>{len(cp.ignore_bins)}</td>"
                        f"<td>{len(cp.illegal_bins)}</td>"
                        "</tr>")

        for cr in sorted(cg.crosses, key=lambda item: item.name):
            covered, total = _bin_stats(cr.bins)
            rows.append(
                "<tr>"
                f"<td>{html.escape(cr.name)} <span class=\"kind\">(cross)</span></td>"
                f"<td>{_pct(cr.coverage)}</td>"
                f"<td>{covered}/{total}</td>"
                "<td>0</td>"
                "<td>0</td>"
                "</tr>")

        if not rows:
            continue

        sections.append(
            "<section class=\"card\">"
            f"<h2>{html.escape(cg.name)}</h2>"
            "<table>"
            "<thead><tr><th>Item</th><th>Coverage</th><th>Covered Bins</th>"
            "<th>Ignore Bins</th><th>Illegal Bins</th></tr></thead>"
            f"<tbody>{''.join(rows)}</tbody>"
            "</table>"
            "</section>")

    return "\n".join(sections)


def _render_html(report, db_path: str) -> str:
    total_covergroups = len(report.covergroups)
    total_coverpoints = sum(len(cg.coverpoints) for cg in report.covergroups)
    total_crosses = sum(len(cg.crosses) for cg in report.covergroups)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Python DV Coverage Dashboard</title>
  <style>
    :root {{
      --bg: #f4f1ea;
      --panel: #fffdf8;
      --ink: #1f2a37;
      --muted: #5f6b7a;
      --line: #d8d2c3;
      --accent: #0f766e;
      --accent-soft: #d7f3ef;
      --warn: #b45309;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
      background: linear-gradient(180deg, #ede7dc 0%, var(--bg) 220px);
      color: var(--ink);
    }}
    header {{
      padding: 32px 40px 20px;
      background: linear-gradient(135deg, #184e77 0%, #1e6091 45%, #34a0a4 100%);
      color: white;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.12);
    }}
    h1 {{ margin: 0; font-size: 34px; }}
    .sub {{
      margin-top: 8px;
      color: rgba(255, 255, 255, 0.88);
      font-size: 14px;
    }}
    main {{
      padding: 28px 40px 40px;
      max-width: 1280px;
      margin: 0 auto;
    }}
    .hero {{
      display: grid;
      grid-template-columns: 1.1fr repeat(3, minmax(0, 1fr));
      gap: 16px;
      margin-top: -34px;
      margin-bottom: 24px;
    }}
    .metric {{
      background: var(--panel);
      border: 1px solid rgba(255, 255, 255, 0.28);
      border-radius: 18px;
      padding: 22px 24px;
      box-shadow: 0 16px 40px rgba(0, 0, 0, 0.08);
    }}
    .metric.big {{
      background: linear-gradient(140deg, #083344 0%, #0f766e 100%);
      color: white;
    }}
    .label {{
      font-size: 12px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--muted);
    }}
    .metric.big .label {{ color: rgba(255, 255, 255, 0.72); }}
    .value {{
      margin-top: 10px;
      font-size: 42px;
      font-weight: 700;
      line-height: 1;
    }}
    .metric.small .value {{ font-size: 30px; color: var(--accent); }}
    .card {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 22px 24px;
      box-shadow: 0 8px 24px rgba(15, 23, 42, 0.05);
      margin-bottom: 20px;
    }}
    h2 {{
      margin: 0 0 16px;
      font-size: 22px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }}
    thead th {{
      text-align: left;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--muted);
      padding: 12px 10px;
      border-bottom: 1px solid var(--line);
    }}
    tbody td {{
      padding: 12px 10px;
      border-bottom: 1px solid #ece7db;
    }}
    tbody tr:last-child td {{ border-bottom: none; }}
    .kind {{
      color: var(--warn);
      font-size: 12px;
      font-weight: 600;
    }}
    .note {{
      color: var(--muted);
      font-size: 14px;
      margin-top: 10px;
    }}
    @media (max-width: 900px) {{
      header, main {{ padding-left: 20px; padding-right: 20px; }}
      .hero {{ grid-template-columns: 1fr; margin-top: 16px; }}
      .value {{ font-size: 34px; }}
    }}
  </style>
</head>
<body>
  <header>
    <h1>Python DV Coverage Dashboard</h1>
    <div class="sub">Merged UCIS XML: {html.escape(db_path)}</div>
  </header>
  <main>
    <section class="hero">
      <article class="metric big">
        <div class="label">Overall Coverage</div>
        <div class="value">{_pct(report.coverage)}</div>
      </article>
      <article class="metric small">
        <div class="label">Covergroups</div>
        <div class="value">{total_covergroups}</div>
      </article>
      <article class="metric small">
        <div class="label">Coverpoints</div>
        <div class="value">{total_coverpoints}</div>
      </article>
      <article class="metric small">
        <div class="label">Crosses</div>
        <div class="value">{total_crosses}</div>
      </article>
    </section>

    <section class="card">
      <h2>Covergroup Summary</h2>
      <table>
        <thead>
          <tr><th>Covergroup</th><th>Coverage</th><th>Coverpoints</th><th>Crosses</th></tr>
        </thead>
        <tbody>
          {_render_covergroup_rows(report)}
        </tbody>
      </table>
      <div class="note">
        Coverage values come from the same UCIS report model used for the
        `dvsim` text dashboard.
      </div>
    </section>

    {_render_coverpoint_sections(report)}
  </main>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True)
    parser.add_argument("--report-dir", required=True)
    parser.add_argument("--dashboard", required=True)
    parser.add_argument("--html", required=True)
    args = parser.parse_args()

    report_dir = Path(args.report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)
    dashboard = Path(args.dashboard)
    dashboard.parent.mkdir(parents=True, exist_ok=True)
    html_path = Path(args.html)
    html_path.parent.mkdir(parents=True, exist_ok=True)

    db = _load_ucis_xml(args.db)
    try:
        report = CoverageReportBuilder.build(db)
        with dashboard.open("w", encoding="utf-8") as fp:
            fp.write("total coverage summary\n")
            fp.write("Score\n")
            fp.write(f"{float(report.coverage):.2f}\n")

        html_path.write_text(_render_html(report, args.db), encoding="utf-8")
    finally:
        db.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())

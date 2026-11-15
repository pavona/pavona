# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Table templates
TABLE_TMPL = """<table class="verification_report_table">
  <thead>
    <tr>
      <th>{col1_name}</th>
      <th>{col2_name}</th>
    </tr>
  </thead>
  <tbody>
{table_entries}
  </tbody>
</table>"""
TABLE_ENTRY_TMPL = """
<tr>
  <td>{col1_entry}</td>
  <td>{col2_entry}</td>
</tr>"""
TABLE_ID_ENTRY_TMPL = """<tr id="{entry_id}">
  <td>{col1_entry}</td>
  <td>{col2_entry}</td>
</tr>"""

# Feature matrices templates
MATRIX_TMPL = """<div class="feature_matrix">
<div class="table-wrapper">
<table>
  <tr>
    <th>{row_title}↓ : {col_title}→</th>
{col_names}
  </tr>
{rows_and_data}
</table>
</div>
</div>
"""

COL_NAME_TMPL = """<th>{col_name}</th>"""

ROW_AND_DATA_TMPL = """<tr>
  <th>{row_name}</th>
{data_entries}
</tr>"""

DATA_ENTRY_TMPL = """<td>{is_mapped}</td>"""

# Reference template
REF_TMPL = """<a href="{ref}">{name}</a>"""

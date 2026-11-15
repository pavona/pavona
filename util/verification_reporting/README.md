# Verification Reporter Tool

`util/verification_reporter.py` generates a verification report for each IP in the repository.
A report shows how the IP's features map to its specification, its testpoints and its tests, and lists the gaps in that mapping.
The reports are Markdown pages that are listed in SUMMARY.md as part of the generated docs.

## Usage
Run the following commands from the repo's root:

```
./util/verification_reporter.py {ip}     # generates a report for one IP (for example aes or alert_handler)
./util/verification_reporter.py all      # generates a report for every IP instantiated in the repo
./util/verification_reporter.py all -v   # verbosity
./util/verification_reporter.py aes -d   # additionally writes per-filter description dumps
./util/verification_reporter.py aes -d 2 # ... and opens a diff comparing the original descriptions to their transformations after applying the third filter (in VS Code)

make -C hw verification_report           # runs the `verification_reporter` for all IPs after regenerating every top
make -C hw top_and_cmdgen                # includes that target
```

## Inputs

For each IP the reporter reads:

  - The IP's block hjson, which must have a `features` list.
  - The IP's testplan, FPV testplan, and chip testplan, if they exist.
  - The IP's specification, (doc/theory_of_operation.md), if it exists.

Features are mapped to testpoints and tests via testplans.
The specification maps features to sections via HTML comments placed around section headings. An example of this is shown below:

```markdown
<!-- BEGIN-FEATURE: AES.FEATURE0 -->
## Example section in AES's theory of operation discussing feature0
...
<!-- END-FEATURE: AES.FEATURE0 -->
```
Markers may nest and overlap, and the same feature may be marked in several places.

## Outputs

Each report is written to `{ip root}/doc/verification_report/`, and stored under `Design Verification/Verification Report` in the SUMMARY.md file:

| File | Contents |
|------|----------|
| `README.md` | Overview page, rendered from `README.md.tpl` |
| `01_feature_report.md` | Feature list, the Feature to Specification matrix and the Feature to Testpoint matrix |
| `02_testpoint_report.md` | Each testpoint with its cleaned description, tests and features |
| `03_test_report.md` | Each test with its testpoints and features |
| `04_unmapped_report.md` | Features, testpoints and tests that are not mapped to one of the other two |

Matrices and tables are written as HTML, and their styling is in `util/site/book-theme/wavejson.css`.

The reports are generated files and should not be edited by hand.
New reports are not added to the site automatically: each report needs entries in the repository's `SUMMARY.md`.

## Where a report is written

Where a report lives decides which chip testpoints it contains.
The IP's `attr` in the top configurations decides where it lives:

  - **Top-agnostic IPs** place one report in `hw/ip/{ip}/doc/verification_report`. It includes the chip testpoints of every top that has a chip testplan for the IP.
  Chip testpoint and test names are suffixed with the top, for example `chip_sw_aes_enc (dragonfly)`, so testpoints from different tops do not collide
  - **Templated IPs** place one report, per top that instantiates them, in `hw/top_{top}/ip_autogen/{ip}/doc/verification_report`.
  Each report reads the hjson, testplans, and specifications for that top's specific instance of the IP in question.
  - **Top-specific IPs** are handled like templated IPs and are placed in `hw/top_{top}/ip/{ip}/doc/verification_report`.

The tops are found from `hw/top_*/data/top_*.hjson`, excluding `scafi_deprecated`.

## Description cleaning

Many testpoint descriptions contain Markdown that will not render as intended, because the result varies by renderer (for example, CommonMark in mdbook versus Python-Markdown in mkdocs).
`verification_reporting/markdown_cleaner.py` cleans each description before it is written.
`MarkdownCleaner.FILTER_MAP` lists the filters in the order they run.
As of now, they are comprised of the following:

| Filter | Fixes |
|--------|-------|
| `format_desc_whitespace` | Converts tabs to spaces and ends each description with a blank line |
| `normalize_desc_whitespace` | Removes the indentation shared by every line, keeping relative indentation |
| `add_space_to_bullet` | Adds the missing space in bullets such as `-foo` |
| `properly_end_bulleted_paragraph` | Separates a bullet list from the paragraph that follows it |
| `properly_start_bulleted_paragraph` | Puts a blank line before a bullet list |
| `fix_links` | Rewrites repository paths such as `doc/...` to be relative to the report's folder |

The cleaner records every description before and after each filter.
With `-d`, these records are written to `verification_reporting/scratch/filtered_descripts/`, one file per filter, so that the effect of a single filter can be reviewed as a diff against the original.
`-d {n}` also opens that diff inside VScode with `code --diff` for the filter at index `n` (counting from 0 in the table above), and `-d -1` opens the diff against all filters applied.

## Files

| File | Purpose |
|------|---------|
| `util/verification_reporter.py` | Command-line tool: loads the inputs, builds the matrices and tables, and writes the reports |
| `util/verification_reporting/markdown_cleaner.py` | Testpoint description cleaning and per-filter recording. |
| `util/verification_reporting/md_report_templates.py` | HTML templates for the tables and matrices |
| `util/verification_reporting/README.md.tpl` | Mako template for each report's overview page |

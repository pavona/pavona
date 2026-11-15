<%
testpoint_desc = ""
if readme_tpl_data["tp_path"]: testpoint_desc += f"- [{ip_name}'s standard testplan]({readme_tpl_data['tp_path']})\n"
if readme_tpl_data["chip_tp_paths"]:
    for top_name in readme_tpl_data["chip_tp_paths"]:
        chip_tp_path = readme_tpl_data["chip_tp_paths"][top_name]
        testpoint_desc += f"- [the {top_name}-level testplan relevant to {ip_name}]({chip_tp_path})\n"
if readme_tpl_data["fpv_tp_path"]: testpoint_desc += f"- [{ip_name}'s Formal Property Verification (FPV) testplan]({readme_tpl_data['fpv_tp_path']})\n"
if testpoint_desc:
    testpoint_desc = " These testpoints are gathered from:\n" + testpoint_desc
spec_string = "[specification](../theory_of_operation.md)" if readme_tpl_data["has_spec"] else "specification"
%># ${readme_tpl_data["full_ip_name"]} Verification Report Overview

The ${ip_name} verification report lists and describes ${ip_name}'s features, tests, testpoints, and specification sections, as well as illustrating the relationship between each. This report is comprised of four documents whose purpose is explained below.

<%text>## [Feature Report](01_feature_report.md)</%text>

Here, ${ip_name}'s features are listed and mapped to both the ${ip_name} ${spec_string} (its Theory of Operation document) and its testpoints.${testpoint_desc}
These mappings are presented as two matrices: a **Feature -> Specification** matrix and a **Feature -> Testpoint** matrix.

**Note:** An IP's testplan contains a list of testpoints.
A testpoint is not a test (i.e., a complete DV simulation configuration).
Rather, it describes a verification objective and may map to zero, one, or more tests.

%if not readme_tpl_data["has_features"]:
**Note: ${ip_name} does not currently contain any features**
%endif

- **Feature -> Specification Matrix**
    - The columns correspond to features.
    - The rows correspond to the sections of the specification that describe each feature.
    - Clicking a matrix entry will navigate to the corresponding section of the specification.

%if not readme_tpl_data["has_features"] or not readme_tpl_data["has_spec"]:
**Note: ${ip_name} does not currently contain a Feature -> Specification Matrix**
%endif

- **Feature -> Testpoint Matrix**
    - The columns correspond to features.
    - The rows correspond to testpoints within the IP's regular/chip-level testplan.
    - Clicking a matrix entry will navigate to the corresponding section of the **Testpoint Report** for additional information.

%if not readme_tpl_data["has_features"] or not readme_tpl_data["has_testpoints"]:
**Note: ${ip_name} does not currently contain a Feature -> Testpoint Matrix**
%endif

<%text>## [IP Testpoint Report](02_testpoint_report.md)</%text>

This report provides a more detailed view of the IP's testpoints, including a description of each testpoint and its associated tests/features, if any.

Clicking a test link will navigate to the corresponding test in the **Test Report**.
Clicking a feature link will navigate to the corresponding feature in the **Feature Report**

%if not readme_tpl_data["has_testpoints"]:
**Note: ${ip_name} does not currently contain any testpoints**
%endif

<%text>## [IP Test Report](03_test_report.md)</%text>

This report lists all tests associated with the IP and maps each test to its corresponding testpoints/features.

Clicking a testpoint link will navigate to the corresponding testpoint in the **Testpoint Report**.
Clicking a feature link will navigate to the corresponding feature in the **Feature Report**

%if not readme_tpl_data["has_tests"]:
**Note: ${ip_name} does not currently contain any tests**
%endif

<%text>## [Unmapped Report](04_unmapped_report.md)</%text>

This report provides a summary of the gaps in the above mapping

It displays the features not currently mapped to a testpoint/test, the testpoints not currently mapped to a feature/test, and the tests not currently mapped to a feature/testpoint.

Clicking a feature link will navigate to the corresponding feature in the **Feature Report**
Clicking a test link will navigate to the corresponding test in the **Test Report**.
Clicking a testpoint link will navigate to the corresponding testpoint in the **Testpoint Report**.

This report is intended to provide a quick "temperature check" of ${ip_name}'s DV effort by highlighting the outstanding verification work that remains.

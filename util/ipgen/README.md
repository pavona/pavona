# Ipgen: Generate IP Blocks From IP Templates

Ipgen is a tool to produce IP blocks from IP templates.

IP templates are pre-processed to render highly customized IP blocks that can be used in a hardware design.
The templates of the source files are written in the Mako templating language, and are rendered by the ipgen tool to become the actual source files.
The templates can be customized through template parameters, which are available within the templates.

Ipgen is a command-line tool and a library.
Users wishing to instantiate an IP template or query it for template parameters will find the command-line application useful.
For use in higher-level scripting, e.g. within [topgen](../topgen/README.md), using ipgen as Python library is recommended.

## Anatomy of an IP template

An IP template is a directory with a well-defined directory layout, which mostly mirrors the standard layout of IP blocks.

An IP template directory has a well-defined structure:

* The IP template name (`<templatename>`) equals the directory name.
* The directory contains a template description file `data/<templatename>.tpldesc.hjson` containing descriptions of the configurable parameters.
  The "default" field of these descriptions are expected to be overridden via the actual configuration parameters.
* The directory also contains some files ending in `.tpl`.
  These files are Mako templates and are rendered into a file in the same relative location without the `.tpl` file extension.

### The template description file

Each IP template comes with a description itself.
This description is contained in the hjson file `data/<templatename>.tpldesc.hjson` in the template directory.

It contains a list of parameter objects.
These objects are dictionaries with the following required keys:

* `name` (string): Name of the template parameter.
* `desc` (string): Human-readable description of the template parameter.
* `type` (string): Data type of the parameter.
  Valid values: `bool`, `int`, `str`, `object`.
* `default` (bool | string | int | dict): The default value of the parameter.
  The type of this should match the `type` argument.
  For convenience, strings are converted into integers on demand (if possible).

#### Example template description file

An exemplary template description file with two parameters, `src` and `target` is shown below.

```hjson
// hw/ip_templates/<templatename>/data/<templatename>.tpldesc.hjson
{
  template_param_list: [
    {
      name: "src"
      desc: "Number of Interrupt Sources"
      type: "int"
      default: "32"
    }
    {
      name: "target"
      desc: "Number of Interrupt Targets"
      type: "int"
      default: "32"
    }
  ]
}
```

### Source file templates (`.tpl` files)

Templates are written in the [Mako templating language](https://www.makotemplates.org/).
All template parameters are available in the rendering context.
For example, a template parameter `src` can be used in the template as `${src}`.

### Ipgen Uniquification

FuseSoC core files should be written in a way that upholds the principle "same name, same public interface".
This means if a FuseSoC core has the same name as another one containing code that became different after template processing, and will be part of the same device, it must also provide the same public interface.

Since SystemVerilog does not provide strong control over which symbols become part of the public API, developers must carefully evaluate their source code.
The public interface includes
- module header(s), e.g. parameter names, ports (names, data types)
- package names and all identifiers within each package, including enum values (but not the values assigned to them)
- defines
While package names and their identifiers are both part of the public interface, uniquification only implies changes to package names because their identifiers are scoped.

If any of those aspects of a source file are templated differently within the same device, the core name referencing the files, the file name itself, and the name of the contained SystemVerilog construct must be made instance-specific.
For example, if file `rtl/flash_ctrl.sv` contained within core `flash_ctrl.core` has two instances that diverge, then the following should happen:
- the core files for the two IPs will be renamed
- the RTL files in question will be renamed
- the module within `flash_ctrl.sv` will be renamed

This is implemented via an extra parameter within the IP template that holds the new name for the template objects, named `module_instance_name`.
This uniquification also needs to be handled by VLNV renaming as explained below.

### VLNV Renaming

The [`instance_vlnv`](./renderer.py) function is available to process VLNV (vendor, library, name, version) strings, which is useful for template core files.
It modifies the VLNV so it becomes top-specific and also supports uniquification.
A VLNV string has the form `<vendor>:<library>:<name>[:<version>]`, where the version is optional.
The `instance_vlnv` function is given a VLNV and has handles to objects that provide the top name and a dictionary holding new names for templates needing uniquification.
If the `module_instance_name` parameter is given, it should also be contained in the uniquification dictionary.
The given VLNV is transformed as follows:

- The vendor string is unchanged.
- The library string gets `<topname>` as a prefix.
- The name is processed as follows:
  - If the name is a key in the uniquification dictionary, it is replaced by the corresponding uniquification dictionary value.
  - If the name starts with a string matching a key in the uniquification dictionary and followed by `_`, the key-matching string is replaced by the corresponding uniquification dictionary value.
  - Otherwise the name stays the same.
- The optional version is preserved.

For example, a `bar_baz.core.tpl` file could look like this:

```yaml
CAPI=2:
name: ${instance_vlnv("pavona:ip:bar_baz")}
```

If the top name was `foo` and the uniquified names dictionary was `{'bar_baz': 'bar_baz_1'}`, the VLNV will become `pavona:foo_ip:bar_baz_1`.
Similarly, the VLNV `pavona:dv:bar_baz_sim` will become `pavona:foo_dv:bar_baz_1_sim`.

The following rules should be applied when creating IP templates:

* Template and use an instance-specific name for all FuseSoC cores which reference templated source files (e.g. SystemVerilog files).
* Template and use an instance-specific name for at least the top-level FuseSoC core.
* Avoid having generic IPs depend on top-specific core files, since that would require using virtual cores, and may introduce subtle incompatibilities.

## Library usage

Ipgen can be used as Python library by importing from the `ipgen` package.
Refer to the comments within the source code for usage information.
[Topgen](../topgen.py) (which [generates IP blocks alongside other top collateral](../topgen/README.md)) can also be considered as an example of using ipgen as a package.

The following example shows how to produce an IP block from an IP template.

```python
from pathlib import Path
from ipgen import IpConfig, IpTemplate, IpBlockRenderer

# Load the template
ip_template = IpTemplate.from_template_path(Path('some/ip/template/directory'))

# Prepare the IP template configuration
params = {}
params['src'] = 17
ip_config = IpConfig("my_instance", params)

# Produce an IP block
renderer = IpBlockRenderer(ip_template, ip_config)
renderer.render(Path("path/to/the/output/directory"))
```

The output produced by ipgen is determined by the chosen renderer.
For most use cases the `IpBlockRenderer` is the right choice, as it produces a full IP block directory.
Refer to the [`ipgen.renderer`](./renderer.py) module for more renderers available with ipgen.

## Command-line usage

The ipgen command-line tool lives in [`util/ipgen.py`](../ipgen.py).
The first argument is typically the action to be executed.

<!-- BEGIN CMDGEN util/selfdoc.py quote:util/ipgen.py --help -->
```
$ util/ipgen.py --help
usage: ipgen.py [-h] ACTION ...

options:
  -h, --help  show this help message and exit

actions:
  Use 'ipgen.py ACTION --help' to learn more about the individual actions.

  ACTION
    describe  Show details about an IP template
    generate  Generate an IP block from an IP template
```
<!-- END CMDGEN -->

### `ipgen generate`

<!-- BEGIN CMDGEN util/selfdoc.py quote:util/ipgen.py generate --help -->
```
$ util/ipgen.py generate --help
usage: ipgen.py generate [-h] [--verbose] -C TEMPLATE_DIR -o OUTDIR [--force]
                         --config-file CONFIG_FILE

Generate an IP block from an IP template

options:
  -h, --help            show this help message and exit
  --verbose             More info messages
  -C TEMPLATE_DIR, --template-dir TEMPLATE_DIR
                        IP template directory
  -o OUTDIR, --outdir OUTDIR
                        output directory for the resulting IP block
  --force, -f           overwrite the output directory, if it exists
  --config-file CONFIG_FILE, -c CONFIG_FILE
                        path to a configuration file
```
<!-- END CMDGEN -->

### `ipgen describe`

<!-- BEGIN CMDGEN util/selfdoc.py quote:util/ipgen.py generate --help -->
```
$ util/ipgen.py generate --help
usage: ipgen.py generate [-h] [--verbose] -C TEMPLATE_DIR -o OUTDIR [--force]
                         --config-file CONFIG_FILE

Generate an IP block from an IP template

options:
  -h, --help            show this help message and exit
  --verbose             More info messages
  -C TEMPLATE_DIR, --template-dir TEMPLATE_DIR
                        IP template directory
  -o OUTDIR, --outdir OUTDIR
                        output directory for the resulting IP block
  --force, -f           overwrite the output directory, if it exists
  --config-file CONFIG_FILE, -c CONFIG_FILE
                        path to a configuration file
```
<!-- END CMDGEN -->


## Limitations

### Changing the IP block name is not supported

Every IP block has a name, which is reflected in many places: in the name of the directory containing the block, in the base name of various files (e.g. the Hjson files in the `data` directory), in the `name` key of the IP description file in `data/<ipname>.hjson`, and many more.

To "rename" an IP block, the content of multiple files, and multiple file names, have to be adjusted to reflect the name of the IP block, while keeping cross-references intact.
Doing that is possible but a non-trivial amount of work, and there is currently no tool support for this.

What is supported and required for most IP templates is the modification of the FuseSoC core name, which can be achieved by templating relevant `.core` files (see above).

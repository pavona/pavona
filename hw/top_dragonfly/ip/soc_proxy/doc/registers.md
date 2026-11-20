# Registers

<!-- BEGIN CMDGEN util/regtool.py -d ./hw/top_dragonfly/ip/soc_proxy/data/soc_proxy.hjson -->
## Summary

| Name                                  | Offset   |   Length | Description                             |
|:--------------------------------------|:---------|---------:|:----------------------------------------|
| soc_proxy.[`ALERT_TEST`](#alert_test) | 0x0      |        4 | Alert Test Register                     |
| soc_proxy.[`DUMMY`](#dummy)           | 0x4      |        4 | Dummy register to keep the device port. |

## ALERT_TEST
Alert Test Register
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "fatal_alert_intg", "bits": 1, "attr": ["wo"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 180}}
```

|  Bits  |  Type  |  Reset  | Name             | Description                                      |
|:------:|:------:|:-------:|:-----------------|:-------------------------------------------------|
|  31:1  |        |         |                  | Reserved                                         |
|   0    |   wo   |   0x0   | fatal_alert_intg | Write 1 to trigger one alert event of this kind. |

## DUMMY
Dummy register to keep the device port.
Always returns 0.
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "dummy", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name   | Description   |
|:------:|:------:|:-------:|:-------|:--------------|
|  31:1  |        |         |        | Reserved      |
|   0    |   ro   |   0x0   | dummy  | Dummy field   |


<!-- END CMDGEN -->

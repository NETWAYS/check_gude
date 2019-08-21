# check_gude

This Plugin will check Gude devices via SNMP.
It will give you the capability to get alarms if values are outside of the given thresholds.
Additionally you get all the values as performance data.
 
## Supported Devices

* Expert Net Control 2151
* Expert Sensor Box 7212 / 7211
* Expert Net Control 2i2o 2100/2150
* Expert Power Control 1100
* Expert PDU Energy 8340
* Expert Net Control 2191 Series

## Required Perl Libraries

* Monitoring::Plugin
* Net::SNMP

## Usage

```
Usage: check_gude.pl [-t <timeout>]
    -H|--host=<host name of the snmp device>
    -C|--community=<snmp community name>
    [ -h|--help ]
    [
      [ -k|--key=<name of snmp key> ]
      [ -w|--warning=<warning threshold> ]
      [ -c|--critical=<critical threshold> ]
      [ -l|--label=<label for this value> ]
      [ -u|--unit=<unit of measurement> ]
      [ -f|--factor=<correction factor for this value> ]
    ]

 -?, --usage
   Print usage information

 -h, --help
   Print detailed help screen

 -V, --version
   Print version information

 --extra-opts=[section][@file]
   Read options from an ini file. See https://www.monitoring-plugins.org/doc/extra-opts.html
   for usage and examples.

 --host
   hostname

 --community
   SNMP community (public)

 --snmpversion
   SNMP version (1 or v2c)

 -k, --key=STRING
   The key or name of the measurement to be checked.
   If omitted, a list of possible keys will be shown.

 -l, --label=STRING
   A label for the measured key.
   If omitted, the name of the key will be used.

 -u, --unit=STRING
   A unit for the measured key.
   If omitted, a default will be used.

 -f, --factor=STRING
   A factor for the value of the measured key.
   If omitted, a default will be used.

 -w, --warning=INTEGER:INTEGER
   Minimum and maximum number of allowable result, outside of which a
   warning will be generated.  If omitted, no warning is generated.

 -c, --critical=INTEGER:INTEGER
   Minimum and maximum number of allowable result, outside of which a
   critical alert will be generated.  If omitted, no alert is generated.

 --short
   shorten the output

 --test
   test - dont exit on errors

 --result
   result - act as if the mesaured result for this key would be ...

 --listoids
   list all enterprise oids as read from device.

 --list
   list known enterprise oids as read from device.

 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 15)

 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)
```

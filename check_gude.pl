#!/usr/bin/perl -w

=pod

=head1 COPYRIGHT


This software is Copyright (c) 2011 NETWAYS GmbH, Birger Schmidt
                               <support@netways.de>

(Except where explicitly superseded by other copyright notices)

=head1 LICENSE

This work is made available to you under the terms of Version 2 of
the GNU General Public License. A copy of that license should have
been provided with this software, but in any event can be snarfed
from http://www.fsf.org.

This work is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301 or visit their web page on the internet at
http://www.fsf.org.


CONTRIBUTION SUBMISSION POLICY:

(The following paragraph is not intended to limit the rights granted
to you to modify and distribute this software under the terms of
the GNU General Public License and is only of importance to you if
you choose to contribute your changes and enhancements to the
community by submitting them to NETWAYS GmbH.)

By intentionally submitting any modifications, corrections or
derivatives to this work, or any other work intended for use with
this Software, to NETWAYS GmbH, you confirm that
you are the copyright holder for those contributions and you grant
NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
royalty-free, perpetual, license to use, copy, create derivative
works based on those contributions, and sublicense and distribute
those contributions and any derivatives thereof.

Nagios and the Nagios logo are registered trademarks of Ethan Galstad.

=cut

# use module
use Nagios::Plugin;
use Getopt::Long;
use Pod::Usage;
use Net::SNMP;
use File::Basename;

use Data::Dumper;
use strict;
use warnings;
use diagnostics; #mainly for debugging, to better understand the messages


##############################################################################
# define and get the command line options.
#   see the command line option guidelines at
#   http://nagiosplug.sourceforge.net/developer-guidelines.html#PLUGOPTIONS

my $PROGNAME = basename $0;
my $VERSION  = 1.0;

# Instantiate Nagios::Plugin object (the 'usage' parameter is mandatory)
my $p = Nagios::Plugin->new(
    usage => "Usage: %s [-t <timeout>]
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
    ]",
    version => $VERSION,
    shortname => " ",
    blurb => 'This plugin will check SNMP values against the thresholds given on command line.
It and will output OK, WARNING or CRITICAL according to the specified thresholds.',

    extra => "

Usage examples:

$PROGNAME -H sensorbox -k Temp1 -w 15 -c 25
may give you:
expert sensor box 7212:  WARNING -  WARNING: Temp1=22.9C (w:15, c:25)

You may check multiple values at a time:
$PROGNAME -H sensorbox -k Temp1 -w 15 -c 25 -k Hygro1 -w 10 -c 20
with the following result:
expert sensor box 7212:  CRITICAL -  CRITICAL: Hygro1=39.1% (w:10, c:20) WARNING: Temp1=22.9C (w:15, c:25)

Further on you may rename keys:
$PROGNAME -H sensorbox -k Temp1 -w 15 -c 25 -k Hygro1 -w 10 -c 20 -l Humidity
with leads to this:
expert sensor box 7212:  CRITICAL -  CRITICAL: Humidity=39% (w:10, c:20)

You can give it an [other] unit
$PROGNAME -H sensorbox -k Temp1 -w 15 -c 25 -u °
may give you:
expert sensor box 7212:  WARNING -  WARNING: Temp1=22.9° (w:15, c:25)

And you can multiply it by a factor:
$PROGNAME -H sensorbox -k Temp1 -w 15 -c 25 -u '' -f 1
may give you:
expert sensor box 7212:  CRITICAL -  CRITICAL: Temp1=229 (w:15, c:25)
note: because there is a default factor of 0.1 for the temperature,
      a factor of 1 leads to this (SNMP gives tenth of a degree often).

Some more examples:

$PROGNAME -H netcontrol -k Temp1 -w 11 -c 21 -k Temp2 -w 12 -c 22
expert net control 2151:  CRITICAL -  CRITICAL: Temp1=-999.9C (w:11, c:21) WARNING: Temp2=21C (w:12, c:22)
there is no sensor connected for Temp1.

Test if there is something connected to the Input1:
$PROGNAME -H nc2i2o -k Input1 -w 1: -c 1:
expert net control 2i2o 2100/2150:  OK -  OK: Input1=1 (w:1:, c:1:)
$PROGNAME -H nc2i2o -k Input1 -w 1: -c 1:
expert net control 2i2o 2100/2150:  CRITICAL -  CRITICAL: Input1=0 (w:1:, c:1:)

Test if there is nothing connected to the Input1:
$PROGNAME -H nc2i2o -k Input1 -w :0 -c :0
expert net control 2i2o 2100/2150:  OK -  OK: Input1=0 (w::0, c::0)
$PROGNAME -H nc2i2o -k Input1 -w :0 -c :0
expert net control 2i2o 2100/2150:  CRITICAL -  CRITICAL: Input1=1 (w::0, c::0)

Everything between 215V and 235V is OK:
$PROGNAME -H powercontrol -k Voltage1 -w 215:235 -c 210:240
Expert Power Control 1100:  OK -  OK: Voltage1=230V (w:215:235, c:210:240)

Test port state:
$PROGNAME -H powercontrol -k PortState1 -w :0 -c :0
Expert Power Control 1100:  CRITICAL -  CRITICAL: PortState1=1 (0=off, 1=on) (w::0, c::0)


THRESHOLDs for -w and -c are specified 'min:max' or 'min:' or ':max'
(or 'max'). If specified '\@min:max', a warning status will be generated
if the count *is* inside the specified range.

See more threshold examples at
http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT

  Examples:

  $PROGNAME -w 10 -c 18 Returns a
  warning if the value is greater than 10,
  or a critical error if it is greater than 18.

  $PROGNAME -w 10: -c 4: Returns a
  warning if the value is less than 10,
  or a critical error if it is less than 4.

  "
);


# Define and document the valid command line options
# usage, help, version, timeout and verbose are defined by default.

$p->add_arg(
    spec => 'host|H=s',
    help => "--host\n   hostname",
    default => undef,
    required => 1,
);

$p->add_arg(
    spec => 'community|C=s',
    help => "--community\n   SNMP community (public)",
    default => "public",
    required => 0,
);

$p->add_arg(
    spec => 'snmpversion=s',
    help => "--snmpversion\n   SNMP version (1 or v2c)",
    default => "v2c",
    required => 0,
);

$p->add_arg(
    spec => 'key|k=s@',
    help =>
qq{-k, --key=STRING
   The key or name of the measurement to be checked.
   If omitted, a list of possible keys will be shown.},
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'label|l=s@',
    help =>
qq{-l, --label=STRING
   A label for the measured key.
   If omitted, the name of the key will be used.},
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'unit|u=s@',
    help =>
qq{-u, --unit=STRING
   A unit for the measured key.
   If omitted, a default will be used.},
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'factor|f=s@',
    help =>
qq{-f, --factor=STRING
   A factor for the value of the measured key.
   If omitted, a default will be used.},
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'warning|w=s@',
    help =>
qq{-w, --warning=INTEGER:INTEGER
   Minimum and maximum number of allowable result, outside of which a
   warning will be generated.  If omitted, no warning is generated.},
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'critical|c=s@',
    help =>
qq{-c, --critical=INTEGER:INTEGER
   Minimum and maximum number of allowable result, outside of which a
   critical alert will be generated.  If omitted, no alert is generated.},
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'short|s',
    help => "--short\n   shorten the output",
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'test',
    help => "--test\n   test - dont exit on errors",
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'result|r=s@',
    help => "--result\n   result - act as if the mesaured result for this key would be ...",
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'listoids',
    help => "--listoids\n   list all enterprise oids as read from device.",
    default => undef,
    required => 0,
);

$p->add_arg(
    spec => 'list',
    help => "--list\n   list known enterprise oids as read from device.",
    default => undef,
    required => 0,
);


# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;

# perform sanity checking on command line options
unless ( defined $p->opts->host ) {
    nagexit(UNKNOWN, "You have to specify a host name!");
}

unless ( defined $p->opts->community ) {
    nagexit(UNKNOWN, "You have to specify a community name!");
}

my $list;
if ( defined $p->opts->list ) {
    $list = 1;
}

my $listoids;
if ( defined $p->opts->listoids ) {
    $listoids = 1;
}

unless ( defined $p->opts->key ) {
    nagadd(UNKNOWN, "No key to check given, try to find one with --list!");
    $list= 1;
}

unless ( defined $p->opts->warning ) {
    nagadd(UNKNOWN, "No warning limits given!");
}

unless ( defined $p->opts->critical ) {
    nagadd(UNKNOWN, "No critical limits given!");
}

if (defined $p->opts->key and defined $p->opts->warning and defined $p->opts->critical and
    ((($#{$p->opts->key} + $#{$p->opts->warning})/2) != $#{$p->opts->critical}) ) {
        nagadd(UNKNOWN, "The number of key, warning and critical arguments differ!");
}

if (defined $p->opts->key and defined $p->opts->label and ($#{$p->opts->key} != $#{$p->opts->label}) ) {
        nagadd(UNKNOWN, "The number of key and label arguments differ!");
}

if (defined $p->opts->key and defined $p->opts->factor and ($#{$p->opts->key} != $#{$p->opts->factor}) ) {
        nagadd(UNKNOWN, "The number of key and factor arguments differ!");
}


# TODO do some checks if there are valid thresholds given for each check.

##############################################################################
# variables

my $sysDescr = '';
my %OIDS = (
    '.1.3.6.1.2.1.1.1.0'    => 'sysDescr',   # expert net control 2151
    '.1.3.6.1.2.1.1.2.0'    => 'enterprise', # .1.3.6.1.4.1.28507.18
    '.1.3.6.1.4.1.28507.18' => {
        # GUDEADS-ENC2101-MIB::enc2101 - expert net control 2151
        '.1.3.6.1.4.1.28507.18.1.3.1.1.0'     => 'portNumber0', # INTEGER: 1
        '.1.3.6.1.4.1.28507.18.1.3.1.2.1.2.1' => 'PortName1',   # STRING: "Output 1"
        '.1.3.6.1.4.1.28507.18.1.6.1.1.2.1'   => 'Temp1',       # INTEGER: 153 10th of degree Celsius
        '.1.3.6.1.4.1.28507.18.1.6.1.1.2.2'   => 'Temp2',       # INTEGER: 168 10th of degree Celsius
        '.1.3.6.1.4.1.28507.18.1.6.1.1.3.1'   => 'Hygro1',      # INTEGER: 416 10th of percentage humidity
        '.1.3.6.1.4.1.28507.18.1.6.1.1.3.2'   => 'Hygro2',      # INTEGER: 389 10th of percentage humidity
    },
    '.1.3.6.1.4.1.28507.16' => {
        # GUDEADS-ENC2102-MIB::enc2102 - expert sensor box 7212
        '.1.3.6.1.4.1.28507.16.1.6.1.1.2.1' => 'Temp1',  # INTEGER: 163 10th of degree Celsius
        '.1.3.6.1.4.1.28507.16.1.6.1.1.3.1' => 'Hygro1', # INTEGER: 393 10th of percentage humidity
    },
    '.1.3.6.1.4.1.28507.31' => {
        # GUDEADS-ENC2102-MIB::enc2101 - expert sensor box 7211-1
        '.1.3.6.1.4.1.28507.31.1.6.1.1.2.1' => 'Temp1', # INTEGER: 163 10th of degree Celsius
    },
    '.1.3.6.1.4.1.28507.15' => {
        # GUDEADS-ENC2I2O-MIB::enc2i2o - expert net control 2i2o 2100/2150
        '.1.3.6.1.4.1.28507.15.1.2.1.0'     => 'portNumber0',       # INTEGER: 2
        '.1.3.6.1.4.1.28507.15.1.2.2.1.2.1' => 'PortName1',         # STRING: "Output1"
        '.1.3.6.1.4.1.28507.15.1.2.2.1.2.2' => 'PortName2',         # STRING: "Output2"
        '.1.3.6.1.4.1.28507.15.1.2.2.1.3.1' => 'PortState1',        # INTEGER: off(0)
        '.1.3.6.1.4.1.28507.15.1.2.2.1.3.2' => 'PortState2',        # INTEGER: off(0)
        '.1.3.6.1.4.1.28507.15.1.2.2.1.4.1' => 'PortSwitchCount1',  # Counter32: 12
        '.1.3.6.1.4.1.28507.15.1.2.2.1.4.2' => 'PortSwitchCount2',  # Counter32: 12
        '.1.3.6.1.4.1.28507.15.1.2.2.1.5.1' => 'PortStartupMode1',  # INTEGER: off(0)
        '.1.3.6.1.4.1.28507.15.1.2.2.1.5.2' => 'PortStartupMode2',  # INTEGER: off(0)
        '.1.3.6.1.4.1.28507.15.1.2.2.1.6.1' => 'PortStartupDelay1', # INTEGER: 0 seconds
        '.1.3.6.1.4.1.28507.15.1.2.2.1.6.2' => 'PortStartupDelay2', # INTEGER: 0 seconds
        '.1.3.6.1.4.1.28507.15.1.2.2.1.7.1' => 'PortRepowerTime1',  # INTEGER: 0 seconds
        '.1.3.6.1.4.1.28507.15.1.2.2.1.7.2' => 'PortRepowerTime2',  # INTEGER: 0 seconds
        '.1.3.6.1.4.1.28507.15.1.3.1.1.2.1' => 'Input1',            # INTEGER: lo(0)
        '.1.3.6.1.4.1.28507.15.1.3.1.1.2.2' => 'Input2',            # INTEGER: lo(0)
        '.1.3.6.1.4.1.28507.15.1.3.2.0'     => 'POE0',              # INTEGER: 1 0 = no POE, 1 = POE available
    },
    '.1.3.6.1.4.1.28507.19' => {
        # GUDEADS-EPC1100-MIB::epc1100 - Expert Power Control 1100
        '.1.3.6.1.4.1.28507.19.1.3.1.1.0'      => 'portNumber0',               # INTEGER: 1
        '.1.3.6.1.4.1.28507.19.1.3.1.2.1.2.1'  => 'PortName1',                 # STRING: "Power Port 1"
        '.1.3.6.1.4.1.28507.19.1.3.1.2.1.3.1'  => 'PortState1',                # INTEGER: on(1)
        '.1.3.6.1.4.1.28507.19.1.3.1.2.1.4.1'  => 'PortSwitchCount1',          # Counter32: 1
        '.1.3.6.1.4.1.28507.19.1.3.1.2.1.5.1'  => 'PortStartupMode1',          # INTEGER: on(1)
        '.1.3.6.1.4.1.28507.19.1.3.1.2.1.6.1'  => 'PortStartupDelay1',         # INTEGER: 0 seconds
        '.1.3.6.1.4.1.28507.19.1.3.1.2.1.7.1'  => 'PortRepowerTime1',          # INTEGER: 0 seconds
        '.1.3.6.1.4.1.28507.19.1.5.1.1.0'      => 'ActivePowerChan0',          # Gauge32: 1
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.2.1'  => 'ChanStatus1',               # INTEGER: 1
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.3.1'  => 'EnergyActive1',             # Gauge32: 2912 Wh
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.4.1'  => 'PowerActive1',              # Gauge32: 112 W
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.5.1'  => 'Current1',                  # Gauge32: 526 mA
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.6.1'  => 'Voltage1',                  # Gauge32: 227 V
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.7.1'  => 'Frequency1',                # Gauge32: 4995 0.01 hz
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.8.1'  => 'PowerFactor1',              # INTEGER: 939 0.001
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.9.1'  => 'Pangle1',                   # INTEGER: 0 0.1 degree
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.10.1' => 'PowerApparent1',            # Gauge32: 119 VA
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.11.1' => 'PowerReactive1',            # Gauge32: 0 VAR
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.12.1' => 'EnergyReactive1',           # Gauge32: 1003 VARh
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.13.1' => 'EnergyActiveResettable1',   # Gauge32: 833 Wh
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.14.1' => 'EnergyReactiveResettable1', # Gauge32: 280 VARh
        '.1.3.6.1.4.1.28507.19.1.5.1.2.1.15.1' => 'ResetTime1',                # Gauge32: 30854 s
        '.1.3.6.1.4.1.28507.19.1.6.1.1.2.1'    => 'Temp1',                     # INTEGER: -9999 0.1 degree Celsius
        '.1.3.6.1.4.1.28507.19.1.6.1.1.3.1'    => 'Hygro1',                    # INTEGER: -9999 0.1 percent humidity
    },
);

my %OIDS_rev = reverse %OIDS;

my %units = (
        'Temp'                     => ['C', 0.1],        # INTEGER: 153 10th of degree Celsius
        'Hygro'                    => ['%', 0.1],        # INTEGER: 416 10th of percentage humidity
        'PortState'                => ' (0=off, 1=on)',  # INTEGER: off(0)
        'EnergyActive'             => 'Wh',              # Gauge32: 2912 Wh
        'PowerActive'              => 'W',               # Gauge32: 112 W
        'Current'                  => 'mA',              # Gauge32: 526 mA
        'Voltage'                  => 'V',               # Gauge32: 227 V
        'Frequency'                => ['hz', 0.01],      # Gauge32: 4995 0.01 hz
        'PowerFactor'              => ['', 0.001],       # INTEGER: 939 0.001
        'PowerApparent'            => 'VA',              # Gauge32: 119 VA
        'PowerReactive'            => 'VAR',             # Gauge32: 0 VAR
        'EnergyReactive'           => 'VARh',            # Gauge32: 1003 VARh
        'EnergyActiveResettable'   => 'Wh',              # Gauge32: 833 Wh
        'ResetTime'                => 's',               # Gauge32: 30854 s
);

my @longoutput;

my $index;

my @unknown;


##############################################################################
# check stuff.


##############################################################################
# take care of timeout option
$SIG{'ALRM'} = sub { nagexit(CRITICAL, "Timeout trying to reach device $p->{opts}->{host}!") };
alarm($p->opts->timeout);


##############################################################################
# gather SNMP
my ($session, $error) = Net::SNMP->session(
    -hostname   =>  $p->opts->host,
    -community  =>  $p->opts->community,
    -version    =>  $p->opts->snmpversion,
    );
if (!$session and !$p->opts->test) { nagexit(CRITICAL, "Failed to reach device $p->{opts}->{host}!") };

my $result;
$result = $session->get_request(
    -varbindlist    =>  [ $OIDS_rev{'sysDescr'},
                          $OIDS_rev{'enterprise'},
                        ]);
if (!$result and !$p->opts->test) { nagexit(CRITICAL, "Failed to query device $p->{opts}->{host}!") };

my $baseoid = $result->{$OIDS_rev{'enterprise'}};
$sysDescr   = $result->{$OIDS_rev{'sysDescr'}};

my %enterprise_OIDS_rev;
eval { %enterprise_OIDS_rev = reverse %{$OIDS{$baseoid}}; };
if($@) {
    nagadd(UNKNOWN, "Sorry, but $baseoid is not known - this device is not supported 'til now!");
    $listoids = 1;
    push (@longoutput,"Get the MIB and try to find something out with:
snmpwalk -M +/path/to/mibs/ -m +'${sysDescr}-MIB' -c public -v $p->{opts}->{snmpversion} $p->{opts}->{host} $baseoid");
}


$result = $session->get_table( -baseoid => $baseoid);
if (!$result and !$p->opts->test) { nagexit(CRITICAL, "Failed to query device $p->{opts}->{host}!") };

# push measured results if wanted
unshift (@longoutput, "enterprise oid: " . $baseoid);
unshift (@longoutput, "sysDescr: " . $sysDescr);
foreach my $oid (sort keys %$result) {
    if ($listoids) {
        push (@longoutput, "$oid " . ((exists($OIDS{$baseoid}{$oid})) ? "($OIDS{$baseoid}{$oid})" : "") ." = $result->{$oid}");
    } elsif ($list and exists($OIDS{$baseoid}{$oid})) {
        push (@longoutput,  "$OIDS{$baseoid}{$oid} = $result->{$oid}");
    }
}

##############################################################################
# put results in the result array (alter if wanted - i.e. multiply by factor)
# put label in the label array
# put unit in the unit array
$index = 0;
foreach my $key (@{$p->{opts}->{key}}) {
    no strict 'refs'; # allow tests on non existing keys
    # fill result from snmp if not given on command line
    unless (defined $p->{opts}->{result}[$index]) {
        if ($enterprise_OIDS_rev{$p->{opts}->{key}[$index]}) {
            $p->{opts}->{result}[$index] = $result->{$enterprise_OIDS_rev{$p->{opts}->{key}[$index]}};
        } else {
            nagexit(UNKNOWN, "No $p->{opts}->{key}[$index] known on $sysDescr $p->{opts}->{host}!");
        }
    }
    # fill label from key if not given on command line
    if (!$p->{opts}->{label}[$index]) {
        $p->{opts}->{label}[$index] = $key;
    }
    # fill unit from %units if not given on command line
    unless (defined $p->{opts}->{unit}[$index]) {
        foreach my $label (sort keys %units) {
            if ($p->{opts}->{key}[$index] =~ /$label/) {
                if (defined $units{$label}[0]) { # it is an array
                    $p->{opts}->{unit}[$index] = $units{$label}[0];
                } else {
                    $p->{opts}->{unit}[$index] = $units{$label};
                }
            } else {
                unless (defined $p->{opts}->{unit}[$index]) { $p->{opts}->{unit}[$index] = ''; }
            }
        }
    }
    # fill factor from %units if not given on command line
    unless (defined $p->{opts}->{factor}[$index]) {
        foreach my $label (sort keys %units) {
            if ($p->{opts}->{key}[$index] =~ /$label/) {
                if (defined $units{$label}[1]) { # it is an array
                    $p->{opts}->{factor}[$index] = $units{$label}[1];
                } else {
                    unless (defined $p->{opts}->{factor}[$index]) { $p->{opts}->{factor}[$index] = 1; }
                }
            }
        }
    }
    # calc result using factor
    if ($p->{opts}->{factor}[$index]) {
        $p->{opts}->{result}[$index] = $p->{opts}->{result}[$index] * $p->{opts}->{factor}[$index];
    }
    $index++;
}


##############################################################################
# check the results in the result array against the defined warning and critical thresholds,
# output the result and exit

$index = 0;
foreach my $key (@{$p->{opts}->{key}}) {   # TODO for 0..array size
    #print ("CHECK RESULTS:  $p->{opts}->{key}[$index] = $p->{opts}->{result}[$index]\n");
    if (defined $p->{opts}->{result}[$index]) {
        # set thresholds
        my $threshold = $p->set_thresholds( warning => $p->{opts}->{warning}[$index], critical => $p->{opts}->{critical}[$index] );
        # add output
        $p->add_message(
            $p->check_threshold($p->{opts}->{result}[$index]), # calc checkresult
            "$p->{opts}->{label}[$index]=$p->{opts}->{result}[$index]$p->{opts}->{unit}[$index] (w:$p->{opts}->{warning}[$index], c:$p->{opts}->{critical}[$index])"
        );
        # add perfdata
        $p->add_perfdata(
            label => $p->{opts}->{label}[$index],
            value => $p->{opts}->{result}[$index],
            # no spaces in unit allowed - a unit with spaces is a description
            uom => ($p->{opts}->{unit}[$index] =~ /^[^\s]+$/) ? $p->{opts}->{unit}[$index] : '',
            threshold => $threshold,
        );
    }
    $index++;
}


nagexit();


##############################################################################
##############################################################################
# define a message add function
##############################################################################
sub nagadd
{
    my $code = shift || UNKNOWN;
    my $message = shift || '';

    if ($code == UNKNOWN) {
        push (@unknown, $message);
    } else {
        $p->add_message($code, $message);
    }
}

##############################################################################
# define a exit function
##############################################################################
sub nagexit
{
    if (defined($session)) { $session->close };
    #print Dumper($p);

    my $code = shift;
    my $message = shift;

    if (defined $code and $code == UNKNOWN) {
        $p->nagios_exit($code, "$message ".join(' ', @unknown)."\n".join("\n", @longoutput));
    } else {
        # compose the message
        if (defined $code) { $p->add_message($code, $message); }
        $message = '';
        if ($p->opts->short) {
            ($code, $message) = $p->check_messages;
        } else {
            $code = $p->check_messages;
            if ($#{$p->{messages}{critical}} > -1) { $message .= " CRITICAL: " . join(' ', @{$p->{messages}{critical}}); }
            if ($#{$p->{messages}{warning}}  > -1) { $message .= " WARNING: "  . join(' ', @{$p->{messages}{warning}}); }
            if ($#{$p->{messages}{ok}}       > -1) { $message .= " OK: "       . join(' ', @{$p->{messages}{ok}}); }
        }
        if ($#unknown > -1) {
            $message = "UNKNOWN: ".join(' ', @unknown)." $message";
            $code = UNKNOWN;
        }
        print (($p->opts->short or $sysDescr eq '') ? "" : "$sysDescr:");
        $p->nagios_exit($code, $message."\n".join("\n", @longoutput));
    }
}


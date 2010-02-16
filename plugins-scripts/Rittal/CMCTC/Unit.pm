package Rittal::CMCTC::Unit;

our @ISA = qw(Rittal::CMCTC);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class  = shift;
  my %params = @_;
  my $self   = {
    runtime      => $params{runtime},
    rawdata      => $params{rawdata},
    index => $params{index},
    cmcTcUnitTypeOfDevice => $params{cmcTcUnitTypeOfDevice},
    cmcTcUnitText => $params{cmcTcUnitText},
    cmcTcUnitSerial => $params{cmcTcUnitSerial},
    cmcTcUnitStatus => $params{cmcTcUnitStatus},
    cmcTcUnitNumberOfSensors => $params{cmcTcUnitNumberOfSensors},
    sensors => [],
    blacklisted  => 0,
    info         => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my $i = $self->{index};
  my $o = $i + 2; # snmp offset
  my $oids = {};
  # get sensors
  $oids->{'cmcTcUnit'.$i.'SensorEntry'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1';
  $oids->{'unit'.$i.'SensorIndex'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.1';
  $oids->{'unit'.$i.'SensorType'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.2';
  $oids->{'unit'.$i.'SensorText'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.3';
  $oids->{'unit'.$i.'SensorStatus'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.4';
  $oids->{'unit'.$i.'SensorVal'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.5';
  $oids->{'unit'.$i.'SensorSetHigh'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.6';
  $oids->{'unit'.$i.'SensorSetLow'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.7';
  $oids->{'unit'.$i.'SensorSetWarn'} = '1.3.6.1.4.1.2606.4.2.'.$o.'.5.2.1.8';
  $oids->{'unit'.$i.'SensorTypeValue'} = {
        1 => 'notAvail',
        2 => 'failure',
        3 => 'overflow',
        4 => 'access',
        5 => 'vibration',
        6 => 'motion',
        7 => 'smoke',
        8 => 'airFlow',
        9 => 'type6',
        10 => 'temperature',
        11 => 'current4to20',
        12 => 'humidity',
        13 => 'userNO',
        14 => 'userNC',
        15 => 'lock',
        16 => 'unlock',
        17 => 'voltOK',
        18 => 'voltage',
        19 => 'fanOK',
        20 => 'readerKeypad',
        21 => 'dutyPWM',
        22 => 'fanStatus',
        23 => 'leakage',
        24 => 'warningRTT',
        25 => 'alarmRTT',
        26 => 'filterRTT',
        27 => 'heatflowRCT',
        28 => 'alarmRCT',
        29 => 'warningRCT',
        30 => 'currentPSM',
        31 => 'statusPSM',
        32 => 'positionPSM',
        33 => 'airFlap',
        34 => 'acoustic',
        35 => 'detACfault',
        36 => 'detACfirstAlarm',
        37 => 'detACmainAlarm',
        40 => 'rpm11LCP',
        41 => 'rpm12LCP',
        42 => 'rpm21LCP',
        43 => 'rpm22LCP',
        44 => 'rpm31LCP',
        45 => 'rpm32LCP',
        46 => 'rpm41LCP',
        47 => 'rpm42LCP',
        48 => 'airTemp11LCP',
        49 => 'airTemp12LCP',
        50 => 'airTemp21LCP',
        51 => 'airTemp22LCP',
        52 => 'airTemp31LCP',
        53 => 'airTemp32LCP',
        54 => 'airTemp41LCP',
        55 => 'airTemp42LCP',
        56 => 'temp1LCP',
        57 => 'temp2LCP',
        58 => 'waterInTemp',
        59 => 'waterOutTemp',
        60 => 'waterFlow',
        61 => 'fanSpeed',
        62 => 'valve',
        63 => 'statusLCP',
        64 => 'waterDelta',
        65 => 'valveActual',
        66 => 'contrTemp2',
        67 => 'condensateDuration',
        68 => 'condensateCycles',
        72 => 'totalKWhPSM',
        73 => 'totalKWPSM',
        74 => 'frequencyPSM',
        75 => 'voltagePSM',
        76 => 'voltStatusPSM',
        77 => 'amperePSM',
        78 => 'ampStatusPSM',
        79 => 'kWPSM',
        80 => 'kWhPSM',
        81 => 'kWhTempPSM',
        100 => 'temperatureWL',
        101 => 'temperature1WL',
        102 => 'humidityWL',
        103 => 'accessWL',
        104 => 'userNOWL',
        105 => 'userNCWL',
        106 => 'analogWL',

  };
  $oids->{'unit'.$i.'SensorStatusValue'} = {
                1 => 'notAvail',
                2 => 'lost',
                3 => 'changed',
                4 => 'ok',
                5 => 'off',
                6 => 'on',
                7 => 'warning',
                8 => 'tooLow',
                9 => 'tooHigh',
  };
  foreach ($self->get_entries($oids, 'cmcTcUnit'.$i.'SensorEntry')) {
    $_->{unitSensorUnit} = $i;
    push(@{$self->{sensors}},
        Rittal::CMCTC::Unit::Sensor->new(%{$_}));
  }
}

sub check {
  my $self = shift;
  my $info = sprintf 'unit %d (%s) has %d sensors connected, has status %s',
      $self->{index},
      $self->{cmcTcUnitTypeOfDevice},
      $self->{cmcTcUnitNumberOfSensors},
      $self->{cmcTcUnitStatus};
  if ($self->{cmcTcUnitStatus} eq 'error') {
    $self->add_message(CRITICAL, $info);
  }
  $self->add_info($info);
  foreach (sort {$a->{unitSensorIndex} <=> $b->{unitSensorIndex}}
      @{$self->{sensors}}) {
    $_->check();
  }
}

sub dump {
  my $self = shift;
  printf "[UNIT_%d]\n", $self->{index};
  foreach (qw(cmcTcUnitTypeOfDevice cmcTcUnitText
      cmcTcUnitSerial cmcTcUnitStatus cmcTcUnitNumberOfSensors)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  foreach (sort {$a->{unitSensorIndex} <=> $b->{unitSensorIndex}}
      @{$self->{sensors}}) {
    $_->dump();
  }
}

1;


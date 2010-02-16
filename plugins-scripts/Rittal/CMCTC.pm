package Rittal::CMCTC;

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };
use Data::Dumper;

our @ISA = qw(Rittal::Device SNMP::Utils);

sub init {
  my $self = shift;
  $self->{unit1} = undef,
  $self->{unit2} = undef,
  $self->{unit3} = undef,
  $self->collect();
  if (! $self->{runtime}->{plugin}->check_messages() && 
      ! exists $self->{noinst_hint}) {
    $self->analyze_device();
    $self->analyze_sensor_units();
    $self->check_device();
    $self->check_sensor_units();
  }
}

sub analyze_device {
  my $self = shift;
  my $oids     = {
    # gehoert zum subsystem
    cmcTcStatusDeviceCMC => '1.3.6.1.4.1.2606.4.2.1.0',
    cmcTcUnitsConnected  => '1.3.6.1.4.1.2606.4.2.2.0',
    cmcTcStatusDeviceCMCValue => {
      1 => 'failed',
      2 => 'ok',
    },
  };
  $self->{cmcTcStatusDeviceCMC} =
        SNMP::Utils::get_object_value($self->{rawdata},
            $oids->{cmcTcStatusDeviceCMC},
            $oids->{cmcTcStatusDeviceCMCValue});
  $self->{cmcTcUnitsConnected} =
        SNMP::Utils::get_object( $self->{rawdata},
            $oids->{cmcTcUnitsConnected});
}

sub analyze_sensor_units {
  my $self = shift;
  my $snmpwalk = $self->{rawdata};
  my $oids1 = {
    cmcTcStatusSensorUnit1      => '1.3.6.1.4.1.2606.4.2.3',
    cmcTcUnit1TypeOfDevice      => '1.3.6.1.4.1.2606.4.2.3.1.0',
    cmcTcUnit1Text              => '1.3.6.1.4.1.2606.4.2.3.2.0',
    cmcTcUnit1Serial            => '1.3.6.1.4.1.2606.4.2.3.3.0',
    cmcTcUnit1Status            => '1.3.6.1.4.1.2606.4.2.3.4.0',
    cmcTcUnit1TypeOfDeviceValue => {
      0 => 'unknown_0',
      1 => 'notAvail',
      2 => 'unitIO',
      3 => 'unitAccess',
      4 => 'unitClimate',
      5 => 'unitFCS',
      6 => 'unitRTT',
      7 => 'unitRTC',
      8 => 'unitPSM',
      9 => 'unitPSM8',
      10 => 'unitPSMMetered',
      11 => 'unitIOWireless',
      12 => 'unitPSM6Schuko',
      13 => 'unitPSM6C19',
    },
    cmcTcUnit1StatusValue => {
      0 => 'unknown_0',
      1 => 'ok',
      2 => 'error',
      3 => 'changed',
      4 => 'quit',
      5 => 'timeout',
      6 => 'detected',
      7 => 'notAvail',
      8 => 'lowPower',
    },
    cmcTcUnit1NumberOfSensors   => '1.3.6.1.4.1.2606.4.2.3.5.1.0',
  };
  my $oids2 = {
    cmcTcStatusSensorUnit2      => '1.3.6.1.4.1.2606.4.2.4',
    cmcTcUnit2TypeOfDevice      => '1.3.6.1.4.1.2606.4.2.4.1.0',
    cmcTcUnit2Text              => '1.3.6.1.4.1.2606.4.2.4.2.0',
    cmcTcUnit2Serial            => '1.3.6.1.4.1.2606.4.2.4.3.0',
    cmcTcUnit2Status            => '1.3.6.1.4.1.2606.4.2.4.4.0',
    cmcTcUnit2TypeOfDeviceValue => {
      0 => 'unknown_0',
      1 => 'notAvail',
      2 => 'unitIO',
      3 => 'unitAccess',
      4 => 'unitClimate',
      5 => 'unitFCS',
      6 => 'unitRTT',
      7 => 'unitRTC',
      8 => 'unitPSM',
      9 => 'unitPSM8',
      10 => 'unitPSMMetered',
      11 => 'unitIOWireless',
      12 => 'unitPSM6Schuko',
      13 => 'unitPSM6C19',
    },
    cmcTcUnit2StatusValue => {
      0 => 'unknown_0',
      1 => 'ok',
      2 => 'error',
      3 => 'changed',
      4 => 'quit',
      5 => 'timeout',
      6 => 'detected',
      7 => 'notAvail',
      8 => 'lowPower',
    },
    cmcTcUnit2NumberOfSensors   => '1.3.6.1.4.1.2606.4.2.4.5.1.0',
  };
  my $oids3 = {
    cmcTcStatusSensorUnit3      => '1.3.6.1.4.1.2606.4.2.5',
    cmcTcUnit3TypeOfDevice      => '1.3.6.1.4.1.2606.4.2.5.1.0',
    cmcTcUnit3Text              => '1.3.6.1.4.1.2606.4.2.5.2.0',
    cmcTcUnit3Serial            => '1.3.6.1.4.1.2606.4.2.5.3.0',
    cmcTcUnit3Status            => '1.3.6.1.4.1.2606.4.2.5.4.0',
    cmcTcUnit3TypeOfDeviceValue => {
      0 => 'unknown_0',
      1 => 'notAvail',
      2 => 'unitIO',
      3 => 'unitAccess',
      4 => 'unitClimate',
      5 => 'unitFCS',
      6 => 'unitRTT',
      7 => 'unitRTC',
      8 => 'unitPSM',
      9 => 'unitPSM8',
      10 => 'unitPSMMetered',
      11 => 'unitIOWireless',
      12 => 'unitPSM6Schuko',
      13 => 'unitPSM6C19',
    },
    cmcTcUnit3StatusValue => {
      0 => 'unknown_0',
      1 => 'ok',
      2 => 'error',
      3 => 'changed',
      4 => 'quit',
      5 => 'timeout',
      6 => 'detected',
      7 => 'notAvail',
      8 => 'lowPower',
    },
    cmcTcUnit3NumberOfSensors   => '1.3.6.1.4.1.2606.4.2.5.5.1.0',
  };
  my $oids4 = {
    cmcTcStatusSensorUnit4      => '1.3.6.1.4.1.2606.4.2.6',
    cmcTcUnit4TypeOfDevice      => '1.3.6.1.4.1.2606.4.2.6.1.0',
    cmcTcUnit4Text              => '1.3.6.1.4.1.2606.4.2.6.2.0',
    cmcTcUnit4Serial            => '1.3.6.1.4.1.2606.4.2.6.3.0',
    cmcTcUnit4Status            => '1.3.6.1.4.1.2606.4.2.6.4.0',
    cmcTcUnit4TypeOfDeviceValue => {
      0 => 'unknown_0',
      1 => 'notAvail',
      2 => 'unitIO',
      3 => 'unitAccess',
      4 => 'unitClimate',
      5 => 'unitFCS',
      6 => 'unitRTT',
      7 => 'unitRTC',
      8 => 'unitPSM',
      9 => 'unitPSM8',
      10 => 'unitPSMMetered',
      11 => 'unitIOWireless',
      12 => 'unitPSM6Schuko',
      13 => 'unitPSM6C19',
    },
    cmcTcUnit4StatusValue => {
      0 => 'unknown_0',
      1 => 'ok',
      2 => 'error',
      3 => 'changed',
      4 => 'quit',
      5 => 'timeout',
      6 => 'detected',
      7 => 'notAvail',
      8 => 'lowPower',
    },
    cmcTcUnit4NumberOfSensors   => '1.3.6.1.4.1.2606.4.2.6.5.1.0',
  };
  $self->{unit1} = Rittal::CMCTC::Unit->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    index => 1,
    cmcTcUnitTypeOfDevice => SNMP::Utils::get_object_value($self->{rawdata},
        $oids1->{cmcTcUnit1TypeOfDevice},
        $oids1->{cmcTcUnit1TypeOfDeviceValue}),
    cmcTcUnitText => SNMP::Utils::get_object( $self->{rawdata},
        $oids1->{cmcTcUnit1Text}),
    cmcTcUnitSerial => SNMP::Utils::get_object( $self->{rawdata},
        $oids1->{cmcTcUnit1Serial}),
    cmcTcUnitStatus => SNMP::Utils::get_object_value($self->{rawdata},
        $oids1->{cmcTcUnit1Status},
        $oids1->{cmcTcUnit1StatusValue}),
    cmcTcUnitNumberOfSensors => SNMP::Utils::get_object( $self->{rawdata},
        $oids1->{cmcTcUnit1NumberOfSensors}),
  );
  $self->{unit2} = Rittal::CMCTC::Unit->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    index => 2,
    cmcTcUnitTypeOfDevice => SNMP::Utils::get_object_value($self->{rawdata},
        $oids2->{cmcTcUnit2TypeOfDevice},
        $oids2->{cmcTcUnit2TypeOfDeviceValue}),
    cmcTcUnitText => SNMP::Utils::get_object( $self->{rawdata},
        $oids2->{cmcTcUnit2Text}),
    cmcTcUnitSerial => SNMP::Utils::get_object( $self->{rawdata},
        $oids2->{cmcTcUnit2Serial}),
    cmcTcUnitStatus => SNMP::Utils::get_object_value($self->{rawdata},
        $oids2->{cmcTcUnit2Status},
        $oids2->{cmcTcUnit2StatusValue}),
    cmcTcUnitNumberOfSensors => SNMP::Utils::get_object( $self->{rawdata},
        $oids2->{cmcTcUnit2NumberOfSensors}),
  );
  $self->{unit3} = Rittal::CMCTC::Unit->new(
    runtime => $self->{runtime},
    rawdata => $self->{rawdata},
    index => 3,
    cmcTcUnitTypeOfDevice => SNMP::Utils::get_object_value($self->{rawdata},
        $oids3->{cmcTcUnit3TypeOfDevice},
        $oids3->{cmcTcUnit3TypeOfDeviceValue}),
    cmcTcUnitText => SNMP::Utils::get_object( $self->{rawdata},
        $oids3->{cmcTcUnit3Text}),
    cmcTcUnitSerial => SNMP::Utils::get_object( $self->{rawdata},
        $oids3->{cmcTcUnit3Serial}),
    cmcTcUnitStatus => SNMP::Utils::get_object_value($self->{rawdata},
        $oids3->{cmcTcUnit3Status},
        $oids3->{cmcTcUnit3StatusValue}),
    cmcTcUnitNumberOfSensors => SNMP::Utils::get_object( $self->{rawdata},
        $oids3->{cmcTcUnit3NumberOfSensors}),
  );
  # although unit4 is defined in the mib, it doesn't exist in reality
}

sub check_device {
  my $self = shift;
  $self->add_info(sprintf 'cmc-tc has %d units connected, has status %s',
      $self->{cmcTcUnitsConnected}, $self->{cmcTcStatusDeviceCMC});
  if ($self->{cmcTcStatusDeviceCMC} eq 'failed') {
    $self->add_message(CRITICAL, sprintf 'general status of cmc-tc is %s',
        $self->{cmcTcStatusDeviceCMC});
  }
  $self->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;;
}

sub check_sensor_units {
  my $self = shift;
  $self->{unit1}->check();
  $self->{unit1}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;;
  $self->{unit2}->check();
  $self->{unit2}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;;
  $self->{unit3}->check();
  $self->{unit3}->dump()
      if $self->{runtime}->{options}->{verbose} >= 2;;
}

sub collect {
  my $self = shift;
  if ($self->{runtime}->{plugin}->opts->snmpwalk) {
    my $cmcTcMibCondition = '1.3.6.1.4.1.2606.4.1.3.0'; # 2=ok
    if (! exists $self->{rawdata}->{$cmcTcMibCondition} &&
        ! exists $self->{rawdata}->{$cmcTcMibCondition}) { # vlt. geht doch was
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (cmctc-mib)');
    }
  } else {
    my $net_snmp_version = Net::SNMP->VERSION(); # 5.002000 or 6.000000
    #$params{'-translate'} = [
    #  -all => 0x0
    #];
    my ($session, $error) = 
        Net::SNMP->session(%{$self->{runtime}->{snmpparams}});
    if (! defined $session) {
      $self->{plugin}->add_message(CRITICAL, 'cannot create session object');
      $self->trace(1, Data::Dumper::Dumper($self->{runtime}->{snmpparams}));
    } else {
      # revMajor is often used for discovery of hp devices
      my $cmcTcMibCondition = '1.3.6.1.4.1.2606.4.1.3.0';
      my $result = $session->get_request(
          -varbindlist => [$cmcTcMibCondition]
      );
      if (!defined($result) || 
          $result->{$cmcTcMibCondition} eq 'noSuchInstance' ||
          $result->{$cmcTcMibCondition} eq 'noSuchObject' ||
          $result->{$cmcTcMibCondition} eq 'endOfMibView') {
        $self->add_message(CRITICAL,
            'snmpwalk returns no health data (rittal-cmc-mib)');
        $session->close;
      }
    }
    if (! $self->{runtime}->{plugin}->check_messages()) {
      # snmp peer is alive
      $self->trace(2, sprintf "Protocol is %s", 
          $self->{runtime}->{snmpparams}->{'-version'});
      my $cmcTc = "1.3.6.1.4.1.2606.4";
      $session->translate;
      my $response = {}; #break the walk up in smaller pieces
      my $tic = time; my $tac = $tic;
      my $response1 = $session->get_table(
          -baseoid => $cmcTc);
      $tac = time;
      $self->trace(2, sprintf "%03d seconds for walk cmcTc (%d oids)",
          $tac - $tic, scalar(keys %{$response1}));
      $session->close;
      map { $response->{$_} = $response1->{$_} } keys %{$response1};
      map { $response->{$_} =~ s/^\s+//; $response->{$_} =~ s/\s+$//; }
          keys %$response;
      $self->{rawdata} = $response;
    }
  }
  return $self->{runtime}->{plugin}->check_messages();
}

sub dump {
  my $self = shift;
  printf "[CMC-TC]\n";
  foreach (qw(cmcTcStatusDeviceCMC cmcTcUnitsConnected)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

1;

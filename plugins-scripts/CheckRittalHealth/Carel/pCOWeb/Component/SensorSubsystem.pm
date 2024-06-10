package CheckRittalHealth::Carel::pCOWeb::Component::SensorSubsystem;
use strict;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);

sub init {
  my $self = shift;
  # Keine Ahnung, was dieser Rotz in diesem Plugin verloren hat
  # Zumindest eine leise Ahnung, von wem es ausging.
  $self->get_snmp_objects('KELVIN-PCOWEB-LCP-DX-MIB', qw(
      gentRelease  agentCode  pCOId1-Status  pCOId1-ErrorsNumber  din1  din2  din3  din4  din5  din6  din7  din8  din9  din10  dobj11  dobj12  dobj13  dobj14  dobj15  dobj16  dout1  dout2  dout3  dout4  dout5  dout6  dout7  dout8  dout9  dout10  dout11  dout12  bms-res-alarm  al-envelope  al-start-fail-lock  mal-start-failure-msk  mal-discharge-ht  dobj34  mal-dp-startup  mal-dp-lubrification-oil  mal-b1  mal-b2  mal-b3  mal-b4  mal-b5  mal-b6  mal-b7  mal-b8  mal-b9  mal-b10  mal-b11  mal-b12  b1-value  b2-value  b3-value  b4-value  b5-value  b6-value  b7-value  b8-value  b9-value  b10-value  b11-value  b12-value  evap-temp  cond-temp  aobj15  aobj16  aobj17  aobj18  aobj19  aobj20  medium-temp-out  medium-temp-in  rotor-speed-rps  motor-current  aobj47  setpoint-lcp  rotor-speed-hz  drive-status  error-code  drive-temp  bus-voltage  motor-voltage  power-req-0-1000-after-envelope  current-hour  current-minute  current-month  current-weekday  current-year  on-off-BMS  envelope-zone  ht-zone  cooling-capacity-after-envelope  valve-steps  y3-AOut3  current-day  fans-speed-percent  fans-speed-rpm  evd-valve-opening-percent
  ));
}

sub check {
  my $self = shift;
  $self->add_info("pCOId1 status is ".$self->{"pCOId1-Status"});
  if ($self->{"pCOId1-Status"} ne "online") {
    $self->add_warning();
  }
  if (defined $self->{"fans-speed-percent"}) {
    $self->set_thresholds(metric => "fans_speed_pct",
        warning => 80,
        critical => 95
    );
    $self->add_message($self->check_thresholds(metric => "fans_speed_pct",
        value => $self->{"fans-speed-percent"}
    ));
  }
}


package CheckRittalHealth::Carel::pCOWeb::Component::SensorSubsystem::Sensor;
use strict;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);

sub finish {
  my $self = shift;
  foreach (keys %{$self}) {
    next if ! /unit\dSensor/;
    if (/unit(\d+)(.*)/) {
      $self->{'unit'.$2} = $self->{$_};
      $self->{unit} = $1;
      delete $self->{$_};
    }
  }
  my @perftypes = qw(airFlow temperature humidity voltage rpm\d+LCP airTemp\d+LCP temp\d+LCP waterInTemp waterOutTemp waterFlow fanSpeed contrTemp2 frequencyPSM voltagePSM voltStatusPSM amperePSM kWPSM kWhPSM kWhTempPSM temperatureWL temperature1WL humidityWL);
  if (grep { $self->{unitSensorType} =~ /^$_$/ } @perftypes) {
    bless $self, "CheckRittalHealth::Carel::pCOWeb::Component::SensorSubsystem::Sensor::Perf";
  }
}

sub check {
  my $self = shift;
  $self->add_info(sprintf "sensor %d.%d (%s) has status %s",
      $self->{unit}, $self->{unitSensorIndex}, $self->{unitSensorText}, $self->{unitSensorStatus});
  if ($self->{unitSensorStatus} eq "ok") {
    $self->add_ok();
  } elsif ($self->{unitSensorStatus} ne "ok") {
    $self->add_critical();
  }
}

package CheckRittalHealth::Carel::pCOWeb::Component::SensorSubsystem::Sensor::Perf;
use strict;
our @ISA = qw(CheckRittalHealth::Carel::pCOWeb::Component::SensorSubsystem::Sensor);

sub check {
  my $self = shift;
  $self->SUPER::check();
  my %perfdata = ();
  $perfdata{metric} = sprintf "%d.%d.%s", $self->{unit}, $self->{unitSensorIndex}, $self->{unitSensorText};
  $perfdata{label} = sprintf "%d.%d.%s", $self->{unit}, $self->{unitSensorIndex}, $self->{unitSensorText};
  if ($self->{unitSensorSetWarn}) {
    if ($self->{unitSensorSetLow}) {
      $perfdata{warning} = $self->{unitSensorSetLow}.":".$self->{unitSensorSetWarn};
    } else {
      $perfdata{warning} = $self->{unitSensorSetWarn};
    }
  }
  if ($self->{unitSensorSetHigh}) {
    $perfdata{critical} = $self->{unitSensorSetHigh};
  }
  $perfdata{value} = $self->{unitSensorValue};
  $self->add_perfdata(%perfdata);
}


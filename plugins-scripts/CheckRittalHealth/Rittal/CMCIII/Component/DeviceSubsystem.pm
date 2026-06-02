package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  $self->mult_snmp_max_msg_size(10);
  $self->get_snmp_objects('RITTAL-CMC-III-MIB',
      qw(cmcIIIUnitStatus cmcIIIUnitType cmcIIIUnitSerial
      cmcIIIUnitProd cmcIIISetTempUnit cmcIIIOverallDevStatus
      cmcIIINumberOfDevs cmcIIINumberOfVars));
  $self->get_snmp_tables('RITTAL-CMC-III-MIB', [
      ['devices', 'cmcIIIDevTable', 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Device'],
      # Only fetch the columns actually used downstream. The device/var
      # indices come from the SNMP instance index (see Variable::finish),
      # so the index columns need not be walked. cmcIIIVarTable can have
      # thousands of rows; walking only these 5 columns instead of all 15
      # cuts the SNMP traffic (and runtime) accordingly.
      ['variables', 'cmcIIIVarTable', 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Variable', undef,
          [qw(cmcIIIVarName cmcIIIVarUnit cmcIIIVarScale cmcIIIVarValueStr cmcIIIVarValueInt)]],
  ]);
  #if ($self->filter_name($dev->{cmcIIIDevIndex})) {
  $self->assign();
}

sub assign {
  my $self = shift;
  foreach my $dev (@{$self->{devices}}) {
    $dev->{variables} = [];
    foreach my $var (@{$self->{variables}}) {
      if ($dev->{cmcIIIDevIndex} eq $var->{cmcIIIVarDeviceIndex}) {
        push(@{$dev->{variables}}, $var);
      }
    }
    @{$dev->{variables}} = sort {
        $a->{cmcIIIVarIndex} <=> $b->{cmcIIIVarIndex} 
    } @{$dev->{variables}};
  }
  @{$self->{devices}} = sort {
      $a->{cmcIIIDevIndex} <=> $b->{cmcIIIDevIndex}
  } @{$self->{devices}};
  foreach (@{$self->{devices}}) {
    $_->group_variables();
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /device::devices::list/) {
    foreach (@{$self->{devices}}) {
      #printf "dev%d\n", $unit if $self->{"unit$unit"}->{cmcTcUnitStatus} ne "notAvail";
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /device::variables::list/) {
    foreach (@{$self->{variables}}) {
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /device::(units|sensors)/) {
    my $info = sprintf 'cmc-tc has %d devices connected, device status is %s',
        $self->{cmcIIINumberOfDevs}, $self->{cmcIIIOverallDevStatus};
    $self->add_info($info);
    if ($self->{cmcIIIOverallDevStatus} ne 'ok') {
      $self->add_critical(sprintf 'overall device status is %s',
          $self->{cmcIIIOverallDevStatus});
    } else {
      $self->add_ok();
    }
    foreach (@{$self->{devices}}) {
      $_->check();
    }
    delete $self->{variables};
  } else {
    $self->no_such_mode();
  }
}


package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Device;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{cmcIIIDevIndex} = $self->{indices}->[0];
  $self->{perf_variables} = [];
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'device %d (%s) has status %s',
      $self->{cmcIIIDevIndex}, $self->{cmcIIIDevName},
      $self->{cmcIIIDevStatus});
  if ($self->{cmcIIIDevStatus} ne 'ok') {
    if ($self->{cmcIIIDevStatusText}) {
      $self->add_critical($self->{cmcIIIDevStatusText});
    } else {
      $self->add_critical();
    }
  }
  foreach (@{$self->{variables}}) {
    $_->check();
  }
  foreach (@{$self->{perf_variables}}) {
    $_->check();
  }
}

sub group_variables {
  my $self = shift;
  my $all_variables = {};
  my $perf_variables = {};
  my $group_names = {};
  my $has_value = {};
  my $has_status = {};
  foreach my $var (@{$self->{variables}}) {
    $all_variables->{$var} = 1; # make an inventory
    if ($var->{cmcIIIVarName} =~ /(.*)\.Value$/) {
      my $prefix = $1;
      $has_value->{$prefix} = $var->{cmcIIIVarValueStr};
    }
  }
  foreach my $var (@{$self->{variables}}) {
    if ($var->{cmcIIIVarName} =~ /(.*)\.Status$/) {
      my $prefix = $1;
      $has_status->{$prefix} = $var->{cmcIIIVarValueStr};
    }
  }
  # First pass: For temperature sensors with both Celsius and Fahrenheit,
  # determine which unit to skip based on validity of the data
  my $skip_temp_unit = {};  # key: device|var_item, value: 'C' or 'F' to skip
  my $temp_data = {};       # Collect C and F data for each temperature sensor

  # Collect all temperature Value and Status data
  foreach my $var (@{$self->{variables}}) {
    next unless $var->{cmcIIIVarName} =~ /^(.*)\.Value$/;
    my $var_item = $1;
    next unless $var_item =~ /Temperature/;
    next unless defined $var->{cmcIIIVarUnit};
    next unless $var->{cmcIIIVarUnit} =~ /degree ([CF])/;

    my $unit = $1;
    my $key = $var->{cmcIIIVarDeviceIndex} . "|" . $var_item . "|" . $unit;

    $temp_data->{$key} = {
      device => $var->{cmcIIIVarDeviceIndex},
      var_item => $var_item,
      unit => $unit,
      value => $var->{cmcIIIVarValueInt},
      value_str => $var->{cmcIIIVarValueStr},
    };
  }

  # Find Status for each temperature group
  foreach my $var (@{$self->{variables}}) {
    next unless $var->{cmcIIIVarName} =~ /^(.*)\.Status$/;
    my $var_item = $1;
    next unless $var_item =~ /Temperature/;

    # Match Status to the correct C or F group by index proximity
    # Status comes AFTER Value in each group
    my $best_match = undef;
    my $best_distance = 999999;

    foreach my $key (keys %{$temp_data}) {
      next unless $key =~ /^\Q$var->{cmcIIIVarDeviceIndex}\E\|\Q$var_item\E\|/;

      # Find the Value index for this group
      foreach my $val_var (@{$self->{variables}}) {
        next unless $val_var->{cmcIIIVarDeviceIndex} eq $var->{cmcIIIVarDeviceIndex};
        next unless $val_var->{cmcIIIVarName} =~ /^\Q$var_item\E\.Value$/;
        next unless defined $val_var->{cmcIIIVarUnit};
        next unless $val_var->{cmcIIIVarUnit} =~ /degree $temp_data->{$key}->{unit}/;

        # Status should come AFTER Value
        if ($val_var->{cmcIIIVarIndex} < $var->{cmcIIIVarIndex}) {
          my $distance = $var->{cmcIIIVarIndex} - $val_var->{cmcIIIVarIndex};
          if ($distance < $best_distance) {
            $best_distance = $distance;
            $best_match = $key;
          }
        }
      }
    }

    if (defined $best_match) {
      $temp_data->{$best_match}->{status} = $var->{cmcIIIVarValueStr};
    }
  }

  # Decide which unit to skip for each device+var_item pair
  my $checked_pairs = {};
  foreach my $key (keys %{$temp_data}) {
    my $data = $temp_data->{$key};
    my $base_key = $data->{device} . "|" . $data->{var_item};

    next if exists $checked_pairs->{$base_key};
    $checked_pairs->{$base_key} = 1;

    my $c_key = $base_key . "|C";
    my $f_key = $base_key . "|F";

    # Only process if both C and F exist
    next unless exists $temp_data->{$c_key} && exists $temp_data->{$f_key};

    my $c_data = $temp_data->{$c_key};
    my $f_data = $temp_data->{$f_key};

    # Check validity: valid if status is not 'undef.' and value is not 0
    my $c_status = $c_data->{status} || '';
    my $f_status = $f_data->{status} || '';
    my $c_valid = ($c_status ne 'undef.' && $c_status ne '' && $c_data->{value} != 0);
    my $f_valid = ($f_status ne 'undef.' && $f_status ne '' && $f_data->{value} != 0);

    # Decision:
    # - If only one is valid, use it (skip the other)
    # - If both valid or both invalid, prefer Celsius (skip Fahrenheit)
    if ($f_valid && !$c_valid) {
      $skip_temp_unit->{$base_key} = 'C';  # Celsius is broken, use Fahrenheit
    } else {
      $skip_temp_unit->{$base_key} = 'F';  # Default: skip Fahrenheit
    }
  }

  foreach (@{$self->{variables}}) {
    $_->{cmcIIIVarName} =~ /^(.*)\.(.*?)$/;
    my $var_item = $1;
    my $var_var = $2;
    # only total power, not power on the single lines
    next if $var_item !~ /(Total.*\.Power\.Active)|Temperature| Temp|Humidity|Supply|Access|Leakage|(Fuses\.Fuse\s+\d+)|(Speed.*Fan\d+)/;
    # skip electric supply, we want cooling/air supply only
    next if $var_item =~ /Supply.*(\d+V|\d+V\d+)$/;
    # looks like a sollwert
    # var 2/109 (Config.Fans.Fan1) has status 80 %
    next if $var_item =~ /Config\.Fan/;

    # Skip temperature variables based on validity check
    my $skip_key = $_->{cmcIIIVarDeviceIndex} . "|" . $var_item;
    if (exists $skip_temp_unit->{$skip_key}) {
      my $unit_to_skip = $skip_temp_unit->{$skip_key};  # 'C' or 'F'

      # Determine which unit THIS variable belongs to
      my $var_unit = undef;

      # If this variable has a degree unit, use it directly
      if (defined $_->{cmcIIIVarUnit} && $_->{cmcIIIVarUnit} =~ /degree ([CF])/) {
        $var_unit = $1;
      } else {
        # No unit (Status, Category, etc.) - find closest .Value to determine unit
        my $current_idx = $_->{cmcIIIVarIndex};
        my $celsius_value_idx = undef;
        my $fahrenheit_value_idx = undef;

        foreach my $other_var (@{$self->{variables}}) {
          next if $other_var->{cmcIIIVarDeviceIndex} ne $_->{cmcIIIVarDeviceIndex};
          next unless $other_var->{cmcIIIVarName} =~ /^\Q$var_item\E\.Value$/;
          next unless defined $other_var->{cmcIIIVarUnit};

          if ($other_var->{cmcIIIVarUnit} =~ /degree C/) {
            $celsius_value_idx = $other_var->{cmcIIIVarIndex};
          } elsif ($other_var->{cmcIIIVarUnit} =~ /degree F/) {
            $fahrenheit_value_idx = $other_var->{cmcIIIVarIndex};
          }
        }

        # Determine unit by index: variables between C_Value and F_Value belong to C,
        # variables at or after F_Value belong to F
        if (defined $celsius_value_idx && defined $fahrenheit_value_idx) {
          if ($current_idx >= $fahrenheit_value_idx) {
            $var_unit = 'F';
          } else {
            $var_unit = 'C';
          }
        }
      }

      # Skip this variable if it belongs to the unit we want to skip
      next if defined $var_unit && $var_unit eq $unit_to_skip;
    }
    $perf_variables->{$var_item} = {} if ! exists $perf_variables->{$var_item};
    $perf_variables->{$var_item}->{valid} = 0 if ! exists $perf_variables->{$var_item}->{valid};
    $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueStr};
    if (exists $has_value->{$var_item}) {
      if ($var_var eq "Value") {
        # variable is cmcIIIVarName: Temperature.Value
        # cmcIIIVarValueStr is pretty ok, like
        # cmcIIIVarValueStr: 26.80 degree C
        # but we can do better:
        if ($_->{cmcIIIVarScale} > 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} * $_->{cmcIIIVarScale};
        } elsif ($_->{cmcIIIVarScale} < 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} / abs($_->{cmcIIIVarScale});
        } else {
          $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueInt};
        }
        if ($var_item =~ /Remote/ and
            # Das Folgende gilt fuer Fans,Valve uvm. nicht nur Temperaturen
            exists $has_status->{$var_item} and
            exists $has_value->{$var_item} and
            $has_status->{$var_item} eq "Off" and
            $has_value->{$var_item} =~ /^0/) {
            # z.b.
            # var 2/183 (Remote.Temperature.DescName) has status Remote Temperature
            # var 2/184 (Remote.Temperature.Value) has status 0.00 degree C
            # var 2/185 (Remote.Temperature.Timeout) has status 0 s
            # var 2/186 (Remote.Temperature.Mode) has status Off
            # var 2/187 (Remote.Temperature.Status) has status Off
            # das Zeug ist wahrsch. nicht mal eingesteckt.
            next;
        }
        $perf_variables->{$var_item}->{cmcIIIVarGroupName} = $var_item;
        $perf_variables->{$var_item}->{cmcIIIVarDeviceIndex} = $_->{cmcIIIVarDeviceIndex};
        $perf_variables->{$var_item}->{cmcIIIVarUnit} = $_->{cmcIIIVarUnit};
        $perf_variables->{$var_item}->{valid} = 1;
      }
    } elsif (exists $has_status->{$var_item}) {
      if ($var_var eq "Status" and
          $var_item =~ /Leakage|Fuses\.Fuse\s+\d+/) {
        # there is no variable cmcIIIVarName: Leakage.Value
        # we need to work with cmcIIIVarName: Leakage.Status
        # which has cmcIIIVarType: status, cmcIIIVarValueStr: OK and
        # cmcIIIVarValueInt: 4, whatever this value means. 
        # 8.1.25: and there can also be cmcIIIVarValueStr: Leakage Sensor
        $perf_variables->{$var_item} = {} if ! exists $perf_variables->{$var_item};
        $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueStr};
        $perf_variables->{$var_item}->{Value} = $_->{cmcIIIVarValueInt};
        $perf_variables->{$var_item}->{cmcIIIVarGroupName} = $var_item;
        $perf_variables->{$var_item}->{cmcIIIVarDeviceIndex} = $_->{cmcIIIVarDeviceIndex};
        $perf_variables->{$var_item}->{cmcIIIVarUnit} = $_->{cmcIIIVarUnit};
        $perf_variables->{$var_item}->{valid} = 1;
      } elsif ($var_var ne "Value" and index($_->{cmcIIIVarUnit}, "degree") != -1 and $var_item =~ /Temperature/) {
        # das sind jetzt die "Values" so eines Multi-Temperatur-Dingens
        # Im Gegensatz zu dem naechsten elsif, der einen Satz Variablen
        # gruppiert, welche nur eine .Value haben
        # var 2/6 (Air.Temperature.DescName) has status Air-Temperatures
        # var 2/7 (Air.Temperature.In-Top) has status 17.3 degree C
        # var 2/8 (Air.Temperature.In-Mid) has status 18.1 degree C
        # var 2/9 (Air.Temperature.In-Bot) has status 18.8 degree C
        # var 2/10 (Air.Temperature.Out-Top) has status 27.0 degree C
        # var 2/11 (Air.Temperature.Out-Mid) has status 26.4 degree C
        # var 2/12 (Air.Temperature.Out-Bot) has status 27.9 degree C
        # var 2/13 (Air.Temperature.Status) has status OK
        # var 2/14 (Air.Temperature.Category) has status 2
        # im Gegensatz zu
        # System.Temperature.DescName
        # System.Temperature.Value
        # System.Temperature.Status
        # ...
        # Temperature.DescName
        # Temperature.Value
        # Temperature.Status
        # ...
        # Coolant.Temperature.Supply.DescName
        # Coolant.Temperature.Supply.Value
        # Coolant.Temperature.Supply.Status
        # ...
        # Coolant.Temperature.Return.DescName
        # Coolant.Temperature.Return.Value
        # Coolant.Temperature.Return.Status
        # ...
        if ($_->{cmcIIIVarScale} > 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} * $_->{cmcIIIVarScale};
        } elsif ($_->{cmcIIIVarScale} < 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} / abs($_->{cmcIIIVarScale});
        } else {
          $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueInt};
        }
        # later in the check, we need to know which of the attributes of
        # a VariableGroup is a metric
        if (! exists $perf_variables->{$var_item}->{perf_vars}) {
          $perf_variables->{$var_item}->{perf_vars} = [$var_var];
        } else {
          push(@{$perf_variables->{$var_item}->{perf_vars}}, $var_var);
        }
        $perf_variables->{$var_item}->{cmcIIIVarGroupName} = $var_item;
        $perf_variables->{$var_item}->{cmcIIIVarDeviceIndex} = $_->{cmcIIIVarDeviceIndex};
        $perf_variables->{$var_item}->{cmcIIIVarUnit} = $_->{cmcIIIVarUnit};
        $perf_variables->{$var_item}->{valid} = 1;
      }
    }
  }
  # Duplicates ist eine Struktur mit DescName als Key und einer Liste aus
  # cmcIIIVarGroupName als Value.
  # Falls also mehrere gleichlautende DescName vergeben wurden (konkretes
  # Beispiel: alle Fans.Current Speed.Fan*.Value haben als DescName "Fan")
  # dann haengt unter dem DescName-Key ein Array mit langen Variablennamen.
  my $duplicates = {};
  foreach (sort keys %{$perf_variables}) {
    next if ! $perf_variables->{$_}->{valid};
    if (exists $duplicates->{$perf_variables->{$_}->{DescName}}) {
      push(@{$duplicates->{$perf_variables->{$_}->{DescName}}}, $perf_variables->{$_}->{cmcIIIVarGroupName});
    } else {
      $duplicates->{$perf_variables->{$_}->{DescName}} = [$perf_variables->{$_}->{cmcIIIVarGroupName}];
    }
  }
  my @to_del = ();
  foreach my $descname (keys %{$duplicates}) {
    # 1 Element, nicht doppelt
    push(@to_del, $descname) if scalar(@{$duplicates->{$descname}}) <= 1;
  }
  foreach (@to_del) {
    delete $duplicates->{$_};
  }
  # Jetzt werden aus denausfuehrlichen Variablennamen die gemeinsamen
  # Bestandteile entfernt.
  $duplicates = $self->remove_common_words($duplicates);
  foreach (sort keys %{$perf_variables}) {
    next if ! $perf_variables->{$_}->{valid};
    # if all the fans have DescName of "Fan", we need to take the numbered
    # version from var_item/cmcIIIVarGroupName
    # var 2/89 (Fans.Current Speed.Fan1.DescName) has status Fan
    # var 2/90 (Fans.Current Speed.Fan1.Value) has status 10 %
    # var 2/91 (Fans.Current Speed.Fan1.Status) has status OK
    # var 2/92 (Fans.Current Speed.Fan1.Category) has status 2
    # var 2/93 (Fans.Current Speed.Fan2.DescName) has status Fan
    # var 2/94 (Fans.Current Speed.Fan2.Value) has status 10 %
    # var 2/95 (Fans.Current Speed.Fan2.Status) has status OK
    # var 2/96 (Fans.Current Speed.Fan2.Category) has status 2
    # var 2/97 (Fans.Current Speed.Fan3.DescName) has status Fan
    # var 2/98 (Fans.Current Speed.Fan3.Value) has status 9 %
    # var 2/99 (Fans.Current Speed.Fan3.Status) has status OK
    # var 2/100 (Fans.Current Speed.Fan3.Category) has status 2
    # var 2/101 (Fans.Current Speed.Fan4.DescName) has status Fan
    # var 2/102 (Fans.Current Speed.Fan4.Value) has status 0 %
    # var 2/103 (Fans.Current Speed.Fan4.Status) has status Inactive
    # var 2/104 (Fans.Current Speed.Fan4.Category) has status 2
    #
    # same with temperatures. we need to add the location
    # var 2/16 (Air Temp.Server In.Top.DescName) has status Air Temperature
    # var 2/17 (Air Temp.Server In.Top.Value) has status 18.40 degree C
    # var 2/18 (Air Temp.Server In.Top.SetPtHighAlarm) has status 50.00 degree C
    # var 2/19 (Air Temp.Server In.Top.SetPtHighWarning) has status 40.00 degree C
    # var 2/20 (Air Temp.Server In.Top.SetPtLowWarning) has status 15.00 degree C
    # var 2/21 (Air Temp.Server In.Top.SetPtLowAlarm) has status 10.00 degree C
    # var 2/22 (Air Temp.Server In.Top.Hysteresis) has status 5.00 %
    # var 2/23 (Air Temp.Server In.Top.Status) has status OK
    # var 2/24 (Air Temp.Server In.Top.Category) has status 2
    # var 2/25 (Air Temp.Server In.Center.DescName) has status Air Temperature
    # var 2/26 (Air Temp.Server In.Center.Value) has status 18.60 degree C
    # var 2/27 (Air Temp.Server In.Center.SetPtHighAlarm) has status 50.00 degree C
    # var 2/28 (Air Temp.Server In.Center.SetPtHighWarning) has status 40.00 degree C
    # var 2/29 (Air Temp.Server In.Center.SetPtLowWarning) has status 15.00 degree C
    # var 2/30 (Air Temp.Server In.Center.SetPtLowAlarm) has status 10.00 degree C
    # var 2/31 (Air Temp.Server In.Center.Hysteresis) has status 5.00 %
    # var 2/32 (Air Temp.Server In.Center.Status) has status OK
    # var 2/33 (Air Temp.Server In.Center.Category) has status 2
    # DRECKSSCHEISSE!!!!! Rein, Raus, alles gleich!!!!
    # var 2/53 (Air Temp.Server Out.Top.DescName) has status Air Temperature
    # var 2/54 (Air Temp.Server Out.Top.Value) has status 22.10 degree C
    # var 2/55 (Air Temp.Server Out.Top.SetPtHighAlarm) has status 50.00 degree C
    # var 2/56 (Air Temp.Server Out.Top.SetPtHighWarning) has status 40.00 degree C
    # var 2/57 (Air Temp.Server Out.Top.SetPtLowWarning) has status 15.00 degree C
    # var 2/58 (Air Temp.Server Out.Top.SetPtLowAlarm) has status 10.00 degree C
    # var 2/59 (Air Temp.Server Out.Top.Hysteresis) has status 5.00 %
    # var 2/60 (Air Temp.Server Out.Top.Status) has status OK
    # var 2/61 (Air Temp.Server Out.Top.Category) has status 2

    # Wenn DescName doppelt, dann ersetzen durch den verkuerzten,
    # aber einzigartigen cmcIIIVarGroupName.
    if ($perf_variables->{$_}->{DescName} and
        exists $duplicates->{$perf_variables->{$_}->{DescName}}) {
      $perf_variables->{$_}->{DescName} = shift @{$duplicates->{$perf_variables->{$_}->{DescName}}};
    }
    push(@{$self->{perf_variables}}, 
        CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup->new(%{$perf_variables->{$_}}));
  }
}

sub split_label {
  my ($self, $label, $separator) = @_;
  if ($separator eq ".") {
    $label =~ s/\./_____/g;
  } else {
    $label =~ s/./_____/g;
  }
  return split /_____/, $label;
}

sub find_common_words {
    my ($self, $split_on, @labels) = @_;
    my @split_labels = map { [$self->split_label($_, $split_on)] } @labels;
    my %word_count;
    # Count the occurrence of each word across all labels
    for my $label (@split_labels) {
        for my $word (@$label) {
            $word_count{$word}++;
        }
    }
    # Identify common words (appear in all labels)
    my @common_words;
    for my $word (keys %word_count) {
        push @common_words, $word if $word_count{$word} == @split_labels;
    }
    return @common_words;
}

sub remove_common_words {
    my ($self, $data) = @_;
    foreach my $key (keys %$data) {
        my $labels = $data->{$key};
        next unless @$labels;
        my @common_words = $self->find_common_words(".", @$labels);
        # Remove the common words from each label
        @$labels = map {
            my $label = $_;
            # Split label into words, remove common words, and rejoin them
            my @words = $self->split_label($label, ".");
            my @remaining_words = grep { my $word = $_; !grep { $_ eq $word } @common_words } @words;
            join('.', @remaining_words);
        } @$labels;
        @$labels = map {
          if ($_ =~ /^$key/) {
            # 'Fan' => ['Fans.Current Speed.Fan1', 'Fans.Current Speed.Fan2',
            # becomes ['Fan1', 'Fan2'...
            $_;
          } else {
            # 'Air Temperature' => ['Air Temp.Server In.Average',
            #                       'Air Temp.Server In.Bottom',
            # becomes
            #     'Air Temperature Server In.Average',
            #     'Air Temperature Server In.Bottom',
            $key." ".$_;
          }
        } @$labels;
    }
    return $data;
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Variable;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{cmcIIIVarDeviceIndex} = $self->{indices}->[0];
  $self->{cmcIIIVarIndex} = $self->{indices}->[1];
  if ($self->{cmcIIIVarValueStr} =~ /^(?:[0-9a-f]{2} )+[0-9a-f]{2}$/i) {
    $self->{cmcIIIVarValueStr} =~ s/\s//g;
    $self->{cmcIIIVarValueStr} =~ s/(([0-9a-f][0-9a-f])+)/pack('H*', $1)/ie;
  }
  if ($self->{cmcIIIVarUnit} =~ /^(?:[0-9a-f]{2} )+[0-9a-f]{2}$/i) {
    $self->{cmcIIIVarUnit} =~ s/\s//g;
    $self->{cmcIIIVarUnit} =~ s/(([0-9a-f][0-9a-f])+)/pack('H*', $1)/ie;
  }
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'var %d/%d (%s) has status %s',
      $self->{cmcIIIVarDeviceIndex}, $self->{cmcIIIVarIndex},
      $self->{cmcIIIVarName}, $self->{cmcIIIVarValueStr});
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
if (! $self->{DescName}) {
	#printf "SCHEIS %s\n", Data::Dumper::Dumper($self);
}
  $self->{DescName} ||= $self->{cmcIIIVarGroupName}; # undef ist mir schon untergekommen
#
#
# JA TOLL, GENAU DANN, WENN ICH DEN SCHEISS AUSROLLEN WILL, KOMMT SOWAS DAHER:
#$VAR1 = bless( {
#  'DescName' => 'Air-Temperatures',
#  'Out-Top' => '27.2 degree C',
#  'Status' => 'OK',
#  'name' => 'dev__Air-Temperatures',
#  'Out-Mid' => '26.6 degree C',
#  'In-Mid' => '18.7 degree C',
#  'In-Top' => '18.0 degree C',
#  'Category' => '2 ',
#  'Out-Bot' => '28.0 degree C',
#  'In-Bot' => '19.5 degree C'
#}, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup' );
#
#
if (! $self->{DescName}) {
 printf "%s\n", Data::Dumper::Dumper($self);
}
  $self->{name} = "dev ".$self->{cmcIIIVarDeviceIndex}." ".$self->{DescName};
  $self->{name} =~ s/\s/_/g;
  foreach (qw(cmcIIIVarUnit)) {
    if (defined $self->{$_}) {
      $self->{$_} =~ s/[^%\w]//g;
    }
  }
  foreach (qw(SetPtHighAlarm SetPtHighWarning SetPtLowAlarm SetPtLowWarning Value cmcIIIVarUnit)) {
    if (defined $self->{$_}) {
      $self->{$_} =~ s/^(-*[\d\.]+).*/$1/g;
    }
  }
  if ($self->{cmcIIIVarGroupName} =~ /Temperature/ and $self->{DescName} =~ /Temperatures/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::MultiTemperatureGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Temperature/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::TemperatureGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Humidity/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::HumidityGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Supply/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::SupplyGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Leakage/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::LeakageGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Access/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::AccessGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Total\.Power\.Active/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::PowerGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Fuse/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::FuseGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Fans.*Speed/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::FanGroup';
  } else {
}
}

sub check {
  my $self = shift;
  # Convert undef. to unknown for better readability
  my $status = $self->{Status};
  if ($status eq 'undef.') {
    $status = 'unknown';
  }
  $self->add_info(sprintf '%s has status %s',
      $self->{name}, $status
  );
  if ($status ne "OK" and $status ne "n.a." and
      # kuehl genug, blaest nicht
      not ($status eq "Inactive" and $self->{DescName} =~ /Fan/)) {
    # Treat unknown status as WARNING, not CRITICAL
    if ($status eq 'unknown') {
      $self->add_warning();
    } else {
      $self->add_critical();
    }
  }
  if ($self->{SetPtLowWarning} || $self->{SetPtHighWarning} ||
      $self->{SetPtLowAlarm} || $self->{SetPtHighAlarm}) {
    # die setzen wir nur, wenn's danach aussieht, als haette einer was
    # eingetragen. 'dev_2_Power_Active'=63;0:0;0:0;; sieht bloed aus.
    $self->set_thresholds(metric => $self->{name},
        warning => $self->{SetPtLowWarning}.":".$self->{SetPtHighWarning},
        critical => $self->{SetPtLowAlarm}.":".$self->{SetPtHighAlarm});
  }
  $self->add_perfdata(label => $self->{name},
      uom => $self->{cmcIIIVarUnit} eq "%" ?
          $self->{cmcIIIVarUnit} : undef,
      value => $self->{Value});
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::FanGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::TemperatureGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::MultiTemperatureGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

sub check {
  my $self = shift;
  foreach (@{$self->{perf_vars}}) {
    $self->add_perfdata(label => $self->{name}.'_'.$_,
        value => $self->{$_});
  }
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::HumidityGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::SupplyGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::LeakageGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

sub check {
  my $self = shift;
  $self->add_info(sprintf '%s has status %s',
      $self->{name}, $self->{Status}
  );
  if ($self->{Status} ne "OK" and $self->{Status} ne "n.a.") {
    $self->add_critical();
  }
  # Zum Kotzen sowas. Weil einer unbedingt seine Lecksensoren im Grafana
  # anzeigen will. Wozu gibt's eigentlich Monitoring?
  # Wenn Nagios Alarm schlägt, dann hol Eimer und Lappen und wisch auf!
  # Aber die Herrschaften starren lieber auf Dashboards und kommen
  # sich cool vor. Wie mich das ankotzt :-(((
  $self->add_perfdata(label => $self->{name},
      value => $self->{Status} eq "OK" ? 0 : 1,
  ) if $self->{Status} ne "n.a.";
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::FuseGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

sub check {
  my $self = shift;
  $self->add_info(sprintf '%s has status %s',
      $self->{name}, $self->{Status}
  );
  if ($self->{Status} ne "OK" and $self->{Status} ne "n.a.") {
    $self->add_critical();
  }
  # Siehe Lecksensoren. Muss unbedingt ins Grafana, unbedingt!
  $self->add_perfdata(label => $self->{name},
      value => $self->{Status} eq "OK" ? 0 : 1,
  ) if $self->{Status} ne "n.a.";
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::PowerGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;


package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::AccessGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

sub check {
  my $self = shift;
  $self->add_info(sprintf '%s has status %s',
      $self->{name}, $self->{Status}
  );
  if ($self->{Status} eq "Open") {
    $self->add_critical_mitigation();
  }
  $self->add_perfdata(label => $self->{name},
      value => $self->{Status} eq "Open" ? 1 : 0,
  );
}

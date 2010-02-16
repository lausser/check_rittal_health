package Rittal::Device;

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    runtime => $params{runtime},
    productname => 'unknown',
  };
  bless $self, $class;
  $self->check_snmp_and_model();
  if (! $self->{runtime}->{plugin}->check_messages()) {
    bless $self, 'Rittal::CMCTC';
    $self->{method} = 'snmp';
  }
  if ($self->{runtime}->{options}->{blacklist} &&
      -f $self->{runtime}->{options}->{blacklist}) {
    $self->{runtime}->{options}->{blacklist} = do {
        local (@ARGV, $/) = $self->{runtime}->{options}->{blacklist}; <> };
  }
  return $self;
}

sub check_snmp_and_model {
# uptime pruefen
# dann whoami
  my $self = shift;
  if ($self->{runtime}->{plugin}->opts->snmpwalk) {
    my $response = {};
    if (! -f $self->{runtime}->{plugin}->opts->snmpwalk) {
      $self->{runtime}->{plugin}->add_message(CRITICAL, 
          sprintf 'file %s not found',
          $self->{runtime}->{plugin}->opts->snmpwalk);
    } elsif (-x $self->{runtime}->{plugin}->opts->snmpwalk) {
      my $cmd = sprintf "%s -On -v%s -c%s %s 1.3.6.1.4.1.2606 2>&1",
          $self->{runtime}->{plugin}->opts->snmpwalk,
          $self->{runtime}->{plugin}->opts->protocol,
          $self->{runtime}->{plugin}->opts->community,
          $self->{runtime}->{plugin}->opts->hostname;
      open(WALK, "$cmd |");
      while (<WALK>) {
        if (/^.*?\.(2606\.[\d\.]+) = .*?: (\-*\d+)/) {
          $response->{'1.3.6.1.4.1.'.$1} = $2;
        } elsif (/^.*?\.(2606\.[\d\.]+) = .*?: "(.*?)"/) {
          $response->{'1.3.6.1.4.1.'.$1} = $2;
          $response->{'1.3.6.1.4.1.'.$1} =~ s/\s+$//;
        }
      }
      close WALK;
    } else {
      open(MESS, $self->{runtime}->{plugin}->opts->snmpwalk);
      while(<MESS>) {
        # SNMPv2-SMI::enterprises.232.6.2.6.7.1.3.1.4 = INTEGER: 6
        if (/^.*?\.(2606\.[\d\.]+) = .*?: (\-*\d+)/) {
          $response->{'1.3.6.1.4.1.'.$1} = $2;
        } elsif (/^.*?\.(2606\.[\d\.]+) = .*?: "(.*?)"/) {
          $response->{'1.3.6.1.4.1.'.$1} = $2;
          $response->{'1.3.6.1.4.1.'.$1} =~ s/\s+$//;
        } if (/^.*?\.(2606\.[\d\.]+) = (\-*\d+)/) {
          $response->{'1.3.6.1.4.1.'.$1} = $2;
        } elsif (/^.*?\.(2606\.[\d\.]+) = "(.*?)"/) {
          $response->{'1.3.6.1.4.1.'.$1} = $2;
          $response->{'1.3.6.1.4.1.'.$1} =~ s/\s+$//;
        }
      }
      close MESS;
    }
    map { $response->{$_} =~ s/^\s+//; $response->{$_} =~ s/\s+$//; }
        keys %$response;
    $self->{rawdata} = $response;
    $self->whoami();
  } else {
    if (eval "require Net::SNMP") {
      my %params = ();
      my $net_snmp_version = Net::SNMP->VERSION(); # 5.002000 or 6.000000
      #$params{'-translate'} = [
      #  -all => 0x0
      #];
      $params{'-hostname'} = $self->{runtime}->{plugin}->opts->hostname;
      $params{'-version'} = $self->{runtime}->{plugin}->opts->protocol;
      if ($self->{runtime}->{plugin}->opts->port) {
        $params{'-port'} = $self->{runtime}->{plugin}->opts->port;
      }
      if ($self->{runtime}->{plugin}->opts->protocol eq '3') {
        $params{'-username'} = $self->{runtime}->{plugin}->opts->username;
        if ($self->{runtime}->{plugin}->opts->authpassword) {
          $params{'-authpassword'} = $self->{runtime}->{plugin}->opts->authpassword;
        }
        if ($self->{runtime}->{plugin}->opts->authprotocol) {
          $params{'-authprotocol'} = $self->{runtime}->{plugin}->opts->authprotocol;
        }
        if ($self->{runtime}->{plugin}->opts->privpassword) {
          $params{'-privpassword'} = $self->{runtime}->{plugin}->opts->privpassword;
        }
        if ($self->{runtime}->{plugin}->opts->privprotocol) {
          $params{'-privprotocol'} = $self->{runtime}->{plugin}->opts->privprotocol;
        }
      } else {
        $params{'-community'} = $self->{runtime}->{plugin}->opts->community;
      }
      $self->{runtime}->{snmpparams} = \%params;
      my ($session, $error) = Net::SNMP->session(%params);
      $self->{session} = $session;
      if (! defined $session) {
        $self->{plugin}->add_message(CRITICAL, 'cannot create session object');
        $self->trace(1, Data::Dumper::Dumper(\%params));
      } else {
        my $sysUpTime = '1.3.6.1.2.1.1.3.0';
        my $result = $session->get_request(
            -varbindlist => [$sysUpTime]
        );
        if (!defined($result)) {
          $self->add_message(CRITICAL,
              'could not contact snmp agent');
          $session->close;
        } else {
          $self->trace(3, 'snmp agent answered');
          $self->whoami();
        }
      }
    } else {
      $self->add_message(CRITICAL,
          'could not find Net::SNMP module');
    }
  }
}

sub whoami {
  my $self = shift;
  my $productname = undef;
  if ($self->{runtime}->{plugin}->opts->snmpwalk) {
    my $cmcTcMibCondition = '1.3.6.1.4.1.2606.4.1.3.0';
    if (exists $self->{rawdata}->{$cmcTcMibCondition}) {
    } else {
      $self->add_message(CRITICAL,
          'snmpwalk returns no mib status name (rittal-cmc-tc-mib)');
    }
  } else {
    my $cmcTcMibCondition = '1.3.6.1.4.1.2606.4.1.3.0';
    my $dummy = '1.3.6.1.2.1.1.5.0';
    if ($self->valid_response($cmcTcMibCondition)) {
    } else {
      $self->add_message(CRITICAL,
          'snmpwalk returns no mib status name (rittal-cmc-tc-mib)');
      $self->{session}->close;
    }
  }
}

sub valid_response {
  my $self = shift;
  my $oid = shift;
  my $result = $self->{session}->get_request(
      -varbindlist => [$oid]
  );
  if (!defined($result) ||
      ! defined $result->{$oid} ||
      $result->{$oid} eq 'noSuchInstance' ||
      $result->{$oid} eq 'noSuchObject' ||
      $result->{$oid} eq 'endOfMibView') {
    return undef;
  } else {
    return $result->{$oid};
  }
}

sub trace {
  my $self = shift;
  my $level = shift;
  my $message = shift;
  if ($self->{runtime}->{options}->{verbose} >= $level) {
    printf "%s\n", $message;
  }
}

sub blacklist {
  my $self = shift;
  my $type = shift;
  my $name = shift;
  $self->{blacklisted} = $self->is_blacklisted($type, $name);
}

sub add_blacklist {
  my $self = shift;
  my $list = shift;
  $self->{runtime}->{options}->{blacklist} = join('/',
      (split('/', $self->{runtime}->{options}->{blacklist}), $list));
}

sub is_blacklisted {
  my $self = shift;
  my $type = shift;
  my $name = shift;
  my $blacklisted = 0;
#  $name =~ s/\:/-/g;
  foreach my $bl_items (split(/\//, $self->{runtime}->{options}->{blacklist})) {
    if ($bl_items =~ /^(\w+):([\:\d\-,]+)$/) {
      my $bl_type = $1;
      my $bl_names = $2;
      foreach my $bl_name (split(/,/, $bl_names)) {
        if ($bl_type eq $type && $bl_name eq $name) {
          $blacklisted = 1;
        }
      }
    } elsif ($bl_items =~ /^(\w+)$/) {
      my $bl_type = $1;
      if ($bl_type eq $type) {
        $blacklisted = 1;
      }
    }
  }
  return $blacklisted;
}

sub add_message {
  my $self = shift;
  my $level = shift;
  my $message = shift;
  $self->{runtime}->{plugin}->add_message($level, $message) 
      unless $self->{blacklisted};
}

sub add_info {
  my $self = shift;
  my $info = shift;
  $info = $self->{blacklisted} ? $info.' (blacklisted)' : $info;
  $self->{info} = $info;
  if (! exists $self->{runtime}->{plugin}->{info}) {
    $self->{runtime}->{plugin}->{info} = [];
  }
  push(@{$self->{runtime}->{plugin}->{info}}, $info);
}

sub annotate_info {
  my $self = shift;
  my $annotation = shift;
  my $lastinfo = pop(@{$self->{runtime}->{plugin}->{info}});
  $lastinfo .= sprintf ' (%s)', $annotation;
  push(@{$self->{runtime}->{plugin}->{info}}, $lastinfo);
}

sub add_extendedinfo {
  my $self = shift;
  my $info = shift;
  $self->{extendedinfo} = $info;
  return if ! $self->{runtime}->{options}->{extendedinfo};
  if (! exists $self->{runtime}->{plugin}->{extendedinfo}) {
    $self->{runtime}->{plugin}->{extendedinfo} = [];
  }
  push(@{$self->{runtime}->{plugin}->{extendedinfo}}, $info);
}

sub get_extendedinfo {
  my $self = shift;
  if (! exists $self->{runtime}->{plugin}->{extendedinfo}) {
    $self->{runtime}->{plugin}->{extendedinfo} = [];
  }
  return join(' ', @{$self->{runtime}->{plugin}->{extendedinfo}});
}

sub add_summary {
  my $self = shift;
  my $summary = shift;
  if (! exists $self->{runtime}->{plugin}->{summary}) {
    $self->{runtime}->{plugin}->{summary} = [];
  }
  push(@{$self->{runtime}->{plugin}->{summary}}, $summary);
}

sub get_summary {
  my $self = shift;
  if (! exists $self->{runtime}->{plugin}->{summary}) {
    $self->{runtime}->{plugin}->{summary} = [];
  }
  return join(', ', @{$self->{runtime}->{plugin}->{summary}});
}

sub dumper {
  my $self = shift;
  my $object = shift;
  my $run = $object->{runtime};
  delete $object->{runtime};
  printf STDERR "%s\n", Data::Dumper::Dumper($object);
  $object->{runtime} = $run;
}

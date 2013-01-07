package NWC::Rittal;

use strict;

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

our @ISA = qw(NWC::Device);

use constant trees => (
  '1.3.6.1.2.1',        # mib-2
  '1.3.6.1.4.1.2606',
);

sub init {
  my $self = shift;
  if ($self->{productname} =~ /Rittal CMC.*III/) {
    bless $self, 'NWC::Rittal::CMCIII';
    $self->debug('using NWC::Rittal::CMCIII');
  } elsif ($self->{productname} =~ /Rittal CMC /) {
    bless $self, 'NWC::Rittal::CMCII';
    $self->debug('using NWC::Rittal::CMCII');
  } else {
    exit 3;
  }
  $self->init();
}


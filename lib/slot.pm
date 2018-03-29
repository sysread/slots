package slot;

=head1 NAME

slot - a simple, comple-time way to declare a class

=head1 SYNOPSIS

  package Point;
  use Types::Standard -types;

  use slot x => Int, rw => 1, req => 1;
  use slot y => Int, rw => 1, req => 1;
  use slot z => Int, rw => 1, def => 0;

  1;

  my $p = Point->new(x => 10, y => 20);
  $p->x(30); # x is set to 30
  $p->y;     # 20
  $p->z;     # 0

=head1 DESCRIPTION

Similar to the L<fields> pragma, C<slot> declares individual fields in a class,
additionally building a constructor and slot accessor methods. Inheritence is
handled in the traditional way, with C<@ISA> or via C<base> or C<parent>
pragmas.

=head2 SLOTS

The import itself accepts two positional parameters: the slot name and an
optional type. The type is validated during construction and in the setter, if
the slot is read-write.

=head1 OPTIONS

=head2 rw

When true, the accessor method accepts a single parameter to modify the slot
value

=head2 req

When true, this constructor will croak if the slot is missing from the named
parameters passed to the constructor.

=head2 def

When present, this value or code ref which generates a value is used as the
default if the slot is missing from the named parameters passed to the
constructor.

=head1 AUTHOR

Jeff Ober <sysread@fastmail.fm>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Jeff Ober.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=cut

use v5.10;
use strict;
use warnings;
no strict 'refs';
use Carp;

our $VERSION = '0.01';

my %CLASS;

sub import {
  my $caller = caller;
  my $class  = shift;
  my $name   = shift;

  my ($type, %param) = (@_ % 2 == 0)
    ? (undef, @_)
    : @_;

  croak "slot ${name}'s type is invalid"
    if defined $type
    && !ref $type
    && !$type->can('inline_check');

  my $rw  = $param{rw}  // 0;
  my $req = $param{req} // 0;
  my $def = $param{def};

  $CLASS{$caller} //= {slot => {}, slots => []};

  $CLASS{$caller}{slot}{$name} = {
    type => $type,
    rw   => $rw,
    req  => $req,
    def  => $def,
  };

  push @{ $CLASS{$caller}{slots} }, $name;

  my $ctor = _build_ctor($caller);
  my $acc  = $rw
    ? _build_setter($class, $name)
    : _build_getter($class, $name);

  my $pkg = qq{
package $caller;
BEGIN {
use Carp;
no warnings 'redefine';
$ctor
$acc
};
  };

  eval $pkg;
  $@ && die $@;
}

sub _build_ctor {
  my $class = shift;

  my $code = q{
sub new \{
  my $class = shift;
  my $param = @_ == 1 ? $_[0] : {@_};
  my $self  = bless {}, $class;
  $self->init($param);
  $self;
\};

};

  $code .= _build_init($class);
  return $code;
}

sub _build_init {
  my $class = shift;
  my $code  = q{
sub init \{
  my ($self, $param) = @_;
};

  if (@{$class . '::ISA'} && $class->SUPER::can('init')) {
    $code .= "  \$self->SUPER::init(\$param);\n";
  }

  foreach my $name (@{ $CLASS{$class}{slots} }) {
    my $slot = $CLASS{$class}{slot}{$name};

    if ($slot->{req} && !defined $slot->{def}) {
      $code .= "  croak '$name is a required field' unless exists \$param->{$name};\n";
    }

    if ($slot->{type}) {
      my $check = $slot->{type}->inline_check("\$param->{$name}");

      $code .= qq{
  if (exists \$param->{$name}) {
    $check || croak '$name did not pass validation as a $slot->{type}';
  }
};
    }

    if (defined $slot->{def}) {
      if (ref $slot->{def} eq 'CODE') {
        $code .= "  \$self->{$name} = exists \$param->{$name} ? \$param->{$name} : \$CLASS{$class}{slot}{$name}{def}->(\$self)";
      } else {
        $code .= "  \$self->{$name} = exists \$param->{$name} ? \$param->{$name} : \$CLASS{$class}{slot}{$name}{def}";
      }
    } else {
      $code .= "  \$self->{$name} = \$param->{$name}";
    }

    $code .= ";\n";
  }

  $code .= "}\n";

  return $code;
}

sub _build_getter {
  my ($class, $name) = @_;
  return qq{
sub $name \{
  croak "$name is protected" if \@_ > 1;
  return \$_[0]->{$name};
\};
  };
}

sub _build_setter {
  my ($class, $name) = @_;
  my $slot = $CLASS{$class}{slot}{$name};

  my $code = qq{
sub $name \{
  if (\@_ > 1) \{
    croak 'usage: \$self->$name | \$self->$name(\$new_value)'
      if \@_ != 2;
};

  if ($slot->{type}) {
    my $check = $slot->{type}->inline_check('$_[1]');
    $code .= "    $check || croak 'value did not pass validation as a $slot->{type}';\n";
  }

  $code .= qq{
    \$_[0]->{$name} = \$_[1];
  \}

  \$_[0]->{$name};
\}
};

  return $code;
}

1;

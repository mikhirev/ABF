package ABF::Platform;

use 5.014002;
use strict;
use warnings;
use Carp;

use JSON;

our @EXPORT_OK = qw();

our @EXPORT = qw();

our $VERSION = '0.00_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my %init = (@_);
    my $self;
    $self->{__PACKAGE__ . '::abf'} = $init{abf} ||
        croak __PACKAGE__ . ' object can be created only by ABF object';
    if ($init{id}) {
        $self->{__PACKAGE__ . '::id'} = $init{id};
    }
    bless($self, $class);
    return $self;
}

sub id {
    my $self = shift;
    croak "$self is not an object" unless ref($self);
    if (@_) {
        $self->{__PACKAGE__ . '::id'} = shift;
        $self->refresh();
    }
    return $self->{__PACKAGE__ . '::id'};
}

sub refresh {
    my $self = shift;
    croak "$self is not an object" unless ref($self);
    my $response = $self->abf()->request('get',
        'platforms/' . $self->id() . '.json');
    my %platformdata = %{decode_json($response->content())};
    foreach (keys $platformdata{platform}) {
        $self->{__PACKAGE__ . "::$_"} = $platformdata{platform}{$_};
    }
}

sub AUTOLOAD {
    my $self = shift;
    croak "$self is not an object" unless ref($self);
    my $field = our $AUTOLOAD;
    return if $field =~ /::DESTROY$/;
    if (! $self->{$field} and ! $self->{updated_at}) {
        $self->refresh();
    }
    croak("No such method $field") unless defined $self->{$field};
    return $self->subentry($self, $field, @_);
}

sub subentry {
    my $self = shift;
    my $link = shift;
    my $field = shift;
    if ($link->{$field} =~ /^HASH\(0x[0-9a-f]+\)$/) {
        my $subfield = shift || croak("not enough arguments");
        return $self->subentry($link->{$field}, $subfield, @_);
    } elsif ($link->{$field} =~ /^ARRAY\(0x[0-9a-f]+\)$/) {
        my @values;
        foreach (@{$link->{$field}}) {
            push @values, $self->subentry($_, @_);
        }
        return \@values;
    } else {
        return $link->{$field};
    }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

ABF::Platform - Perl class for ABF platforms.

=head1 SYNOPSIS

  use ABF;
  my $pl = $abf->platform(id => $id);

=head1 DESCRIPTION

TBW

=head2 EXPORT

None by default.

=head1 SEE ALSO

TBW

=head1 AUTHOR

Dmitry Mikhirev <mikhirev@mezon.ru>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Dmitry Mikhirev

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut

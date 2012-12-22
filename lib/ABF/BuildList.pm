package ABF::BuildList;

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
    my $response = $self->abf()->request('get',
        'build_lists/' . $self->id() . '.json');
    my %buildlistdata = %{decode_json($response->content())};
    foreach (keys $buildlistdata{build_list}) {
        $self->{__PACKAGE__ . "::$_"} = $buildlistdata{build_list}{$_};
    }
}

sub strstatus {
    my $self = shift;
    croak "$self is not an object" unless ref($self);
    my %statuses = (0       => 'built',
                    1       => 'platform not found',
                    2       => 'platform pending',
                    3       => 'project not found',
                    4       => 'version not found',
                    666     => 'build error',
                    2000    => 'build pending',
                    3000    => 'build started',
                    4000    => 'waiting',
                    5000    => 'canceled',
                    6000    => 'published',
                    7000    => 'publishing',
                    8000    => 'publishing error',
                    9000    => 'rejected'
                );
    return $statuses{$self->status()};
}

sub cancel {
    my $self = shift;
    my $response = $self->abf()->request('get',
        'build_lists/' . $self->id() . '/cancel.json');
    return decode_json($response->content());
}

sub publish {
    my $self = shift;
    my $response = $self->abf()->request('get',
        'build_lists/' . $self->id() . '/publish.json');
    return decode_json($response->content());
}

sub reject {
    my $self = shift;
    my $response = $self->abf()->request('get',
        'build_lists/' . $self->id() . '/reject_publish.json');
    return decode_json($response->content());
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

=head1 NAME

ABF::BuildList - Perl class for ABF build lists.

=head1 SYNOPSIS

  my $bl = $abf->buildlist(id => $id);

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

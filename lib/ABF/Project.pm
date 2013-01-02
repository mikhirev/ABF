package ABF::Project;

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
    $self->{'abf'} = $init{abf} ||
        croak __PACKAGE__ . ' object can be created only by ABF object';
    if ($init{id}) {
        $self->{__PACKAGE__ . '::id'} = $init{id};
    } elsif ($init{fullname}) {
        $self->{__PACKAGE__ . '::fullname'} = $init{fullname};
    }
    bless($self, $class);
    $self->refresh()
        if $self->{__PACKAGE__ . '::id'} || $self->{__PACKAGE__ . '::fullname'};
    return $self;
}

sub id {
    my $self = shift;
    croak "$self is not an object" unless ref($self);
    if (@_) {
        $self->{__PACKAGE__ . '::id'} = shift;
        $self->refresh();
    } else {
        unless ($self->{__PACKAGE__ . '::id'}) {
            my ($owner, $name) = $self->fullname() =~ m|^([^/]+)/([^/]+)$|;
            croak "Invalid package fullname" unless $name && $owner;
            my $response = $self->{abf}->request('get', 'projects/get_id.json',
                name    => $name,
                owner   => $owner
            );
            my %projdata = %{decode_json($response->content())};
            $self->{__PACKAGE__ . '::id'} = $projdata{project}{id};
            $self->refresh();
        }
    }
    return $self->{__PACKAGE__ . '::id'};
}

sub fullname {
    my $self = shift;
    croak "$self is not an object" unless ref($self);
    if (@_) {
        $self->{__PACKAGE__ . '::fullname'} = shift;
        $self->{__PACKAGE__ . '::id'} = 0;
        $self->refresh();
    }
    return $self->{__PACKAGE__ . '::fullname'};
}

sub refresh {
    my $self = shift;
    my $response = $self->{abf}->request('get',
        'projects/' . $self->id() . '.json');
    my %projdata = %{decode_json($response->content())};
    foreach (keys $projdata{project}) {
        $self->{__PACKAGE__ . "::$_"} = $projdata{project}{$_};
    }
}

sub createbuildlist {
    my $self = shift;
    $self->{abf}->createbuildlist(project_id => $self->id(), @_);
}

sub AUTOLOAD {
    my $self = shift;
    croak "$self is not an object" unless ref($self);
    my $field = our $AUTOLOAD;
    return if $field =~ /::DESTROY$/;
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

ABF - Perl extension for blah blah blah

=head1 SYNOPSIS

  use ABF;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for ABF, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Dmitry Mikhirev, <mikhirev@mezon.ru>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012, 2013 by Dmitry Mikhirev

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

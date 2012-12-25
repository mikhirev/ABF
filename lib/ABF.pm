package ABF;

use 5.014002;
use strict;
use warnings;

#use AutoLoader qw(AUTOLOAD);

use Class::Struct;
use LWP::UserAgent;
use JSON;

use ABF::Project;
use ABF::BuildList;
use ABF::Platform;

our @EXPORT_OK = qw();

our @EXPORT = qw();

our $VERSION = '0.00_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

our $ratelimit;
our $ratelimit_remain;

struct ABF => {
    baseurl     => '$',
    login       => '$',
    password    => '$',
};

sub project {
    my $self = shift;
    ABF::Project->new(abf => $self, @_);
}

sub buildlist {
    my $self = shift;
    ABF::BuildList->new(abf => $self, @_);
}

sub platform {
    my $self = shift;
    ABF::Platform->new(abf => $self, @_);
}

sub arches {
    my $self = shift;
    my $response = $self->request('get', 'arches.json');
    my $responsedata = decode_json($response->content());
    return $responsedata->{architectures};
}

sub buildlists {
    my $self = shift;
    my $page = shift || 1;
    my $per_page = shift || 10;
    my %filter = (@_);
    my @args = (page => $page, per_page => $per_page);
    my $i = 0;
    while ($i < @_) {
        push @args, "filter[$_[$i]]", $_[$i+1];
        $i += 2;
    }
    my $response = $self->request('get', 'build_lists.json', @args);
    my $list = decode_json($response->content());
    my @results;
    foreach (@{$list->{build_lists}}) {
        push @results, $self->buildlist(abf => $self, %$_);
    }
    return @results;
}

sub createbuildlist {
    my $self = shift;
    my %params = (@_);

    foreach ('project_id', 'commit_hash', 'update_type',
        'save_to_repository_id', 'build_for_platform_id',
        'auto_publish', 'include_repos', 'arch_id')
    {
        croak("required parameter $_ not specified") unless defined($params{$_});
    }

    # parameters that must be numeric
    foreach ('project_id', 'save_to_repository_id',
            'build_for_platform_id', 'arch_id') {
        $params{$_} += 0;
    }
    foreach (@{$params{include_repos}}) {
        $_ += 0;
    }

    # parameters that must be boolean
    foreach ('auto_publish', 'build_requires') {
        $params{$_} = $params{$_} ? JSON::true : JSON::false;
    }

    my $requestdata = { build_list => \%params };
    my $response = $self->request('post', 'build_lists.json', encode_json($requestdata));
    my $responsedata = decode_json($response->content());
    croak($responsedata->{build_list}{message}) unless $responsedata->{build_list}{id};
    return $self->buildlist(id  => $responsedata->{build_list}{id});
}

sub platformsforbuild {
    my $self = shift;
    my $response = $self->request('get', 'platforms/platforms_for_build.json');
    my $list = decode_json($response->content());
    my @results;
    foreach (@{$list->{platforms}}) {
        push @results, $self->platform(abf => $self, %$_);
    }
    return @results;
}

sub apiurl {
    my $self = shift;
    my $url = $self->baseurl() . "/api/v1/";
    my $login = $self->login();
    my $password = $self->password();
    return $url;
}

sub ua {
    my $self = shift;
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
    my ($protocol, $host, $port) = $self->baseurl() =~ m|^(\w+)://([\w.-]+)(?::(\d+))?|;
    $port = $protocol eq 'https' ? 443 : 80 unless $port;
    $ua->credentials("$host:$port", 'Application', $self->login(), $self->password());
    return $ua;
}

sub ratelimit {
    my $self = shift;
    $self->request('get', 'user.json') unless $ratelimit;
    return $ratelimit;
}

sub ratelimit_remain {
    my $self = shift;
    $self->request('get', 'user.json') unless $ratelimit_remain;
    return $ratelimit_remain;
}

sub request ($$$@) {
    my $self = shift;
    my $type = shift;
    my $path = shift;
    my $ua = $self->ua();
    my $response;
    for ($type) {
        if (m/^get$/i) {
            my $url = $self->apiurl() . $path . '?';
            my $i = 0;
            while ($i < @_) {
                $url .= "$_[$i]=$_[$i+1]&";
                $i += 2;
            }
            my $req = HTTP::Request->new(GET => $url);
            $req->authorization_basic($self->login(), $self->password());
            $response = $ua->request($req);
        } elsif (m/^put$/i) {
            my $data = pop;
            my $url = $self->apiurl() . $path . '?';
            my $i = 0;
            while ($i < @_) {
                $url .= "$_[$i]=$_[$i+1]&";
                $i += 2;
            }
            my $req = HTTP::Request->new(PUT, $url, @_, Content => $data);
            $req->authorization_basic($self->login(), $self->password());
            $response = $ua->request($req);
        } elsif (m/^post$/i) {
            my $data = pop;
            my $url = $self->apiurl() . $path . '?';
            my $i = 0;
            while ($i < @_) {
                $url .= "$_[$i]=$_[$i+1]&";
                $i += 2;
            }
            my $req = HTTP::Request->new(POST => $url, @_,
                        'Content-Type'  => 'application/json',
                        Content         => $data);
            $req->authorization_basic($self->login(), $self->password());
            $response = $ua->request($req);
        } else {
            croak("Only GET, POST and PUT requests allowed");
        }
    }
    croak ('Request failed: ' . $response->code() . ' ' . $response->message())
        if  $response->is_error();
    $ratelimit = $response->header("X-RateLimit-Limit");
    $ratelimit_remain = $response->header("X-RateLimit-Remaining");
    return $response;
}

sub timeout {
    if (defined $ratelimit_remain and $ratelimit_remain < $ratelimit) {
        sleep 3600 / $ratelimit + 1;
    }
}

1;
__END__

=head1 NAME

ABF - Perl interface for ABF (Automated Build Farm).

=head1 SYNOPSIS

  use ABF;
  my $abf = ABF::new( baseurl  => https://abf.rosalinux.ru,
                      login    => $login,
                      password => $password );

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

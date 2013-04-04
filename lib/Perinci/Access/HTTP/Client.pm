package Perinci::Access::HTTP::Client;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

use parent qw(Perinci::Access::Base);

our $VERSION = '0.07'; # VERSION

my @logging_methods = Log::Any->logging_methods();

sub _init {
    my ($self) = @_;

    # attributes
    $self->{retries}         //= 2;
    $self->{retry_delay}     //= 3;
    $self->{lwp_implementor} //= undef;
    unless (defined $self->{log_level}) {
        $self->{log_level} =
            $ENV{TRACE} ? 6 :
                $ENV{DEBUG} ? 5 :
                    $ENV{VERBOSE} ? 4 :
                        $ENV{QUIET} ? 2 :
                            0;
    }
    $self->{log_callback}    //= undef;
}

sub request {

    my ($self, $action, $server_url, $extra) = @_;
    $log->tracef(
        "=> %s\::request(action=%s, server_url=%s, extra=%s)",
        __PACKAGE__, $action, $server_url, $extra);
    return [400, "Please specify server_url"] unless $server_url;
    my $rreq = { action=>$action,
                 ua=>"Perinci/".($Perinci::Access::HTTP::Client::VERSION//"?"),
                 %{$extra // {}} };
    my $res = $self->check_request($rreq);
    return $res if $res;

    state $json = do {
        require JSON;
        JSON->new->allow_nonref;
    };

    state $ua;
    if (!$ua) {
        require LWP::UserAgent;
        $ua = LWP::UserAgent->new;
        $ua->env_proxy;
        $ua->set_my_handler(
            "response_data",
            sub {
                my ($resp, $ua, $h, $data) = @_;

                # we collect HTTP response body into _buffer first. if
                # __mark_log is set then we need to separate each log message
                # and response part. otherwise, everything just needs to go to
                # __body.
                #$log->tracef("got resp: %s (%d bytes)", $data, length($data));

                if ($ua->{__mark_log}) {
                    $ua->{__buffer} .= $data;
                    if ($ua->{__buffer} =~ /\A([lr])(\d+) /) {
                        my ($chtype, $chlen) = ($1, $2);
                        # not enough data yet
                        my $hlen = 1+length($chlen)+1;
                        return 1 unless length($ua->{__buffer}) >= $hlen + $chlen;
                        my $chdata = substr($ua->{__buffer}, $hlen, $chlen);
                        substr($ua->{__buffer}, 0, $hlen+$chlen) = "";
                        if ($chtype eq 'l') {
                            if ($self->{log_callback}) {
                                $self->{log_callback}->($chdata);
                            } else {
                                $chdata =~ s/^\[(\w+)\]//;
                                my $method = $1;
                                $method = "error" unless $method ~~ @logging_methods;
                                $log->$method("[$server_url] $chdata");
                            }
                            return 1;
                        } elsif ($chtype eq 'r') {
                            $ua->{__body} .= $chdata;
                        } else {
                            $ua->{__body} = "[500,\"Unknown chunk type $chtype".
                                "try updating ${\(__PACKAGE__)} version\"]";
                            return 0;
                        }
                    } else {
                        $ua->{__body} = "[500,\"Invalid response from server,".
                            " server is probably using older version of ".
                                "Riap::HTTP server library\"]";
                        return 0;
                    }
                } else {
                    $ua->{__body} .= $data;
                }
            }
        );
    }

    # need to set due to closure?
    $ua->{__buffer}    = "";
    $ua->{__body}      = "";

    if (defined $self->{user}) {
        require URI;
        my $suri = URI->new($server_url);
        my $host = $suri->host;
        my $port = $suri->port;
        $ua->credentials(
            "$host:$port",
            $self->{realm} // "restricted area",
            $self->{user},
            $self->{password}
        );
    }

    my $http_req = HTTP::Request->new(POST => $server_url);
    for (keys %$rreq) {
        next if /\A(?:args|fmt|loglevel|marklog|_.*)\z/;
        my $hk = "x-riap-$_";
        my $hv = $rreq->{$_};
        if (!defined($hv) || ref($hv)) {
            $hk = "$hk-j-";
            $hv = $json->encode($hv);
        }
        $http_req->header($hk => $hv);
    }
    $ua->{__mark_log} = $self->{log_level} ? 1:0;
    $http_req->header('x-riap-marklog'  => $ua->{__mark_log});
    $http_req->header('x-riap-loglevel' => $self->{log_level});
    $http_req->header('x-riap-fmt'      => 'json');

    my %args;
    if ($rreq->{args}) {
        for (keys %{$rreq->{args}}) {
            $args{$_} = $rreq->{args}{$_};
        }
    }
    my $args_s = $json->encode(\%args);
    $http_req->header('Content-Type' => 'application/json');
    $http_req->header('Content-Length' => length($args_s));
    $http_req->content($args_s);

    #use Data::Dump; dd $http_req;

    my $attempts = 0;
    my $do_retry;
    my $http0_res;
    while (1) {
        $do_retry = 0;

        my $old_imp;
        if ($self->{lwp_implementor}) {
            my $imp = $self->{lwp_implementor};
            $imp =~ s!::!/!g; $imp .= ".pm";
            $old_imp = LWP::Protocol::implementor("http");
            eval "require $imp" or
                return [500, "Can't load $self->{lwp_implementor}: $@"];
            LWP::Protocol::implementor("http", $imp);
        }

        eval { $http0_res = $ua->request($http_req) };
        my $eval_err = $@;

        if ($old_imp) {
            LWP::Protocol::implementor("http", $old_imp);
        }

        return [500, "Client died: $eval_err"] if $eval_err;

        if ($http0_res->code >= 500) {
            $log->warnf("Network failure (%d - %s), retrying ...",
                        $http0_res->code, $http0_res->message);
            $do_retry++;
        }

        if ($do_retry && $attempts++ < $self->{retries}) {
            sleep $self->{retry_delay};
        } else {
            last;
        }
    }

    return [500, "Network failure: ".$http0_res->code." - ".$http0_res->message]
        unless $http0_res->is_success;
    return [500, "Empty response from server (1)"]
        if !length($http0_res->content);
    return [500, "Empty response from server (2)"]
        unless length($ua->{__body});

    eval {
        $log->tracef("body: %s", $ua->{__body});
        $res = $json->decode($ua->{__body});
    };
    my $eval_err = $@;
    return [500, "Invalid JSON from server: $eval_err"] if $eval_err;

    #use Data::Dump; dd $res;
    $res;
}

1;
# ABSTRACT: Riap::HTTP client



__END__
=pod

=head1 NAME

Perinci::Access::HTTP::Client - Riap::HTTP client

=head1 VERSION

version 0.07

=head1 SYNOPSIS

 use Perinci::Access::HTTP::Client;
 my $pa = Perinci::Access::HTTP::Client->new;

 # list all functions in package
 my $res = $pa->request(list => 'http://localhost:5000/api/',
                        {uri=>'/Some/Module/', type=>'function'});
 # -> [200, "OK", ['/Some/Module/mult2', '/Some/Module/mult2']]

 # call function
 my $res = $pa->request(call => 'http://localhost:5000/api/',
                        {uri=>'/Some/Module/mult2', args=>{a=>2, b=>3}});
 # -> [200, "OK", 6]

 # get function metadata
 $res = $pa->request(meta => 'http://localhost:5000/api/',
                     {uri=>'/Foo/Bar/multn'});
 # -> [200, "OK", {v=>1.1, summary=>'Multiple many numbers', ...}]

 # pass HTTP credentials
 my $pa = Perinci::Access::HTTP::Client->new(user => 'admin', password=>'123');
 my $res = $pa->request(call => '...', {...});
 # -> [200, "OK", 'result']

=head1 DESCRIPTION

This class implements L<Riap::HTTP> client.

This class uses L<Log::Any> for logging.

=for Pod::Coverage ^action_.+

=head1 ATTRIBUTES

=over

=item * realm => STR

For HTTP basic authentication. Defaults to "restricted area" (this is the
default realm used by L<Plack::Middleware::Auth::Basic>).

=item * user => STR

For HTTP basic authentication.

=item * password => STR

For HTTP basic authentication.

=back

=head1 METHODS

=head2 PKG->new(%attrs) => OBJ

Instantiate object. Known attributes:

=over

=item * retries => INT (default 2)

Number of retries to do on network failure. Setting it to 0 will disable
retries.

=item * retry_delay => INT (default 3)

Number of seconds to wait between retries.

=item * lwp_implementor => STR

If specified, use this class for http LWP::Protocol::implementor(). For example,
to access Unix socket server instead of a normal TCP one, set this to
'LWP::Protocol::http::SocketUnix'.

=item * log_level => INT (default 0 or from environment)

Will be fed into Riap request key 'loglevel' (if >0). Note that some servers
might forbid setting log level.

If TRACE environment variable is true, default log_level will be set to 6. If
DEBUG, 5. If VERBOSE, 4. If quiet, 1. Else 0.

=item * log_callback => CODE

Pass log messages from the server to this subroutine. If not specified, log
messages will be "rethrown" into Log::Any logging methods (e.g. $log->warn(),
$log->debug(), etc).

=back

=head2 $pa->request($action => $server_url, \%extra_keys) => $res

Send Riap request to $server_url. Note that $server_url is the HTTP URL of Riap
server. You will need to specify code entity URI via C<uri> key in %extra_keys.

C<%extra_keys> is optional and contains additional Riap request keys (except
 C<action>, which is taken from C<$action>).

=head1 FAQ

=head1 TODO

=over

=item * attr: hook/handler to pass to $ua

=item * attr: use custom $ua object

=back

=head1 SEE ALSO

L<Perinci::Access::HTTP::Server>

L<Riap>, L<Rinci>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


package WebService::LDR;

use warnings;
use strict;
use WWW::Mechanize;
use base qw/Class::Accessor::Fast/;
use Carp qw//;
use JSON qw/from_json/;
use Data::Dumper;
use Encode;
use WebService::LDR::Response;
use Scalar::Util qw/looks_like_number/;
use Try::Tiny;

__PACKAGE__->mk_accessors( qw/apiKey/ );

=head1 NAME

WebService::LDR - The thin Perl interface to L<Livedoor Reader|http://reader.livedoor.com>

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WebService::LDR;

    my $ldr = WebService::LDR->new(
        user => 'your livedoor_id',
        pass => 'your password',
    )->login;

    for my $uri (@uris) {
        my $res = $ldr->subscribe($uri) or do {
            warn "cannot discover feed at $uri"; next;
        };
        $res->isSuccess
            ? print "success\n";
            : print "failed\n";
    }

=head1 DESCRIPTION

WebService::LDR is a very thin interface to L<Livedoor reader|http://reader.livedoor.com>,
which is well-known online RSS reader in Japan.  With this module, you can (un)?subscribe
feeds, retrieve entry information which you haven't read, add and clear pins, etc. from
your script.

=cut

my $DEBUG;

my $urls = {
    login   => 'https://member.livedoor.com/login/',    # url for login
    base    => 'http://reader.livedoor.com/api',        # url of API base
    notify  => 'http://rpc.reader.livedoor.com/notify', # url for unread pin number
};

=head1 METHODS

=head2 new

    my $ldr = WebService::LDR->new(
        user  => 'your livedoor_id',
        pass  => 'your password',
        debug => 1,
    );

Creates and returns a new C<WebService::LDR> object.  C<new> takes two mandatory 
parameters, C<user> and C<pass>, and two optional parameters C<debug> and 
C<mech> as written above.

C<user> is your livedoor_id and C<pass> is its password.
With C<debug> being true value, C<WebService::LDR> prints its request and
response to I<STDOUT> for debug purpose.

C<mech> must be an hashref, and is passed directory to L<WWW::Mechanize>
constructor C<new>.

=cut

sub new {
    my ($class, %args) = @_;

    _validate( %args );
    my $mech_conf = delete $args{mech} || [];

    my $self = bless {
        user   => delete $args{user},
        pass   => delete $args{pass},
        mech   => WWW::Mechanize->new( @$mech_conf ),
    }, $class;

    if ( $args{debug} ) {
        require Data::Dumper;
        $DEBUG = 1;
    }

    $self;
}

sub _validate {
    my (%args) = @_;

    my $user = $args{user};
    my $pass = $args{pass};
    for my $param ($user, $pass) {
        $param or Carp::croak "username and/or password is missing\n";
    }

    $DEBUG = $args{debug};
}

=head2 login

    $ldr->login;

Logins to Livedoor Reader with livedoor_id and password
passed to constructor.  As this method returns C<WebService::LDR> object,
it can be used with methodchain.

    my $ldr = WebService::LDR->new(
        user => 'hoge',
        pass => 'fuga',
    )->login;

It croaks when login failed.

=cut

sub login {
    my ($self) = @_;

    $self->{mech}->get( $urls->{login} );
    if ( $self->{mech}->content =~ /name="loginForm"/ ) {

        $DEBUG && debug( "submit form to login as an user=[", $self->{user}, "]" );
        $self->{mech}->submit_form( 
            form_name => 'loginForm',
            fields => {
                livedoor_id => $self->{user},
                password    => $self->{pass},
            }
        );
        if ( $self->{mech}->content =~ /class="error-messages"/ ) {
            $DEBUG && debug( "login failed" );
            Carp::croak "Failed to login LivedoorReader";
        }
        else {
            $DEBUG && debug( "login success" );
        }
    }
    $self;
}

=head2 auto_discovery

    my @discoveries = $ldr->auto_discovery( "http://d.hatena.ne.jp/kiririmode" );

Discovers RSS URLs on URL passed as an parameter.  Parameter can be everything
which is evaluated as string, such as L<URI> class.

It returns list of C<WebService::LDR::Response::Discovery>s.

=head3 WebService::LDR::Response::Discovery

WebService::LDR::Response::Discovery is just a thin wrapper, and has only
getters and setters (latter may not be used).

It has following getters.  Most of their return value can be easily guessed with
its method name.

=over 4

=item * link

=item * subscribe_id

=item * title

=item * feedlink

=item * subscribers_count

=back

=cut

sub auto_discovery {
    my ($self, $url) = @_;

    my $json = $self->_request( '/feed/discover' => { url => "$url" } );
    map { WebService::LDR::Response::Discovery->new( $_ ) } @$json;
}

=head2 subscribe

    my $result = $ldr->subscribe($uri) or 
        warn "cannot discover feed on $uri";

Subscribes feed on specified URI.  It returns WebService::LDR::Response::Result
on success, and undef on failure of discovering feed on the URI.

Argument can be string URI, C<URI> class, or everything having C<feedlink> method
which returns RSS URI.  If a string or C<URI> is passed as a parameter, it executes
C<auto_discovery> to discover its feed, and then subscribes the feed.

=head3 WebService::LDR::Response::Result

WebService::LDR::Response::Result is also a wrapper of response from Livedoor
Reader, and has the followings.

=over 4

=item * subscribe_id

=item * ErrorCode

=item * isSuccess

=back

=cut

sub subscribe {
    my ($self, $arg) = @_;

    my $link;
    if ( ref($arg) || ! $arg->isa('URI') ) {
        $link = $self->_feedlink($arg);
    }
    else {
        $link = $arg;
    }

    my @discovered = $self->auto_discovery($link) or do {
        $DEBUG && debug("cannot discover feed on $link");
        return;
    };

    WebService::LDR::Response::Result->new( 
        $self->_request( '/feed/subscribe' => { feedlink => $discovered[0]->feedlink->as_string } )
    );
}

sub unsubscribe {
    my ($self, $arg ) = @_;

    $arg or Carp::croak("arg is undefined");

    my $subscribe_id = $arg;
    my @discovered;
    if ( ! looks_like_number($arg) ) {
        @discovered= $self->auto_discovery($arg) or do {
            $DEBUG && debug("cannot discover feed on $arg");
            return;
        };
        $subscribe_id = $discovered[0]->subscribe_id;
    }

    WebService::LDR::Response::Unsubscribe->new( 
        $self->_request( '/feed/unsubscribe' => { subscribe_id => $subscribe_id } )
    );
}

sub get_feed_all {
    my ($self) = @_;

    map { WebService::LDR::Response::Feed->new($_) } 
        @{ $self->_request( '/subs' => { unread => 0 } ) };
}

sub get_feed_unread {
    my ($self) = @_;

    map { WebService::LDR::Response::Feed->new($_) } 
        @{ $self->_request( '/subs' => { unread => 1 } ) };
}

sub get_unread_of {
    my ($self, $arg) = @_;

    my $subscribe_id = $self->_subscribe_id($arg);
    WebService::LDR::Response::Article->new(
        $self->_request( '/unread' => { subscribe_id => $subscribe_id } )
    );
}

sub get_all_of {
    my ($self, $arg1, $offset, $limit) = @_;

    my $subscribe_id = $self->_subscribe_id($arg1);
    my $param = {
        subscribe_id => $subscribe_id,
        $offset? ( offset => $offset ) : (),
        $limit?  ( limit  => $limit  ) : (),
    };

    WebService::LDR::Response::Article->new(
        $self->_request( '/all' => $param )
    );
}

sub read {
    my ($self, $arg) = @_;

    my $subscribe_id = $self->_subscribe_id($arg);
    WebService::LDR::Response::Result->new(
        $self->_request('/touch_all' => { subscribe_id => $subscribe_id })
    );
}

sub set_rate {
    my ($self, $arg, $rate) = @_;

    Carp::croak "rate is undef"        unless defined $rate;
    Carp::croak "rate is not a number" unless looks_like_number($rate);

    my $subscribe_id = $self->_subscribe_id($arg);
    WebService::LDR::Response::Result->new(
        $self->_request('/feed/set_rate' => {
            subscribe_id => $subscribe_id,
            rate         => $rate
        })
    );
}

sub folders {
    my ($self) = @_;

    WebService::LDR::Response::Folders->new(
        $self->_request('/folders')
    );
}

sub make_folder {
    my ($self, $name) = @_;

    Carp::croak "name isn't specified" unless $name;
    
    $self->_require_apiKey;
    WebService::LDR::Response::Result->new(
        $self->_request('/folder/create' => {
            name => $name
        })
    );
}

sub delete_folder {
    my ($self, $name) = @_;

    my $folders = $self->folders();

    my $id;
    if ( $folders->exists($name) ) {
        $id = $folders->name2id->{$name};
    } elsif ( looks_like_number($name)  ) {
        $id = $name;
    } else {
        Carp::croak "$name is not a directory name, or hasn't created yet";
    }

    WebService::LDR::Response::Result->new(
        $self->_request('/folder/delete' => {
            folder_id => $id
        })
    );
}

sub move_folder {
    my ($self, $feed, $dirname) = @_;

    my $subscribe_id = $self->_subscribe_id($feed);

    WebService::LDR::Response::Result->new(
        $self->_request('/feed/move' => {
            subscribe_id => $subscribe_id,
            to           => $dirname
        })
    );
}

sub get_pin_all {
    my ($self) = @_;

    map { WebService::LDR::Response::Pin->new($_) }
        @{ $self->_request('/pin/all') };
}

sub add_pin {
    my ($self, $link, $title) = @_;

    $self->_require_apiKey;
    WebService::LDR::Response::Result->new(
        $self->_request('/pin/add' => {
            link  => "$link",
            title => $title,
        })
    );
}

sub delete_pin {
    my ($self, $arg) = @_;

    my $link = $self->_link($arg);

    $self->_require_apiKey;
    WebService::LDR::Response::Result->new(
        $self->_request('/pin/remove' => {
            link => "$link",
        })
    );
}

sub clear_pin {
    my ($self) = @_;

    $self->_require_apiKey;
    WebService::LDR::Response::Result->new(
        $self->_request('/pin/clear')
    );
}

sub _require_apiKey {
    my ($self) = @_;

    unless ($self->apiKey) {
        $self->auto_discovery('http://www.google.co.jp');
    }
}

sub _subscribe_id {
    my ($self, $arg) = @_;
    $self->_extract($arg, "subscribe_id");
}

sub _feedlink {
    my ($self, $arg) = @_;
    $self->_extract($arg, "feedlink");
}

sub _link {
    my ($self, $arg) = @_;
    $self->_extract($arg, "link");
}

sub _extract {
    my ($self, $arg, $prop) = @_;

    unless( defined $arg ) {
        Carp::croak "argument isn't defined";
    }

    if ( ref $arg ) {
        if ( $arg->can($prop) ) {
            return defined $arg->$prop()
                ? $arg->$prop()
                : Carp::croak( "$prop isn't defined" );
        }
        else { Carp::croak "argument cannot call $prop !"; }
    }
    $arg;
}

sub _request {
    my ($self, $api, $opt) = @_;

    my $url = $urls->{base} . $api;
    $DEBUG && debug("POSTing $url with ", Data::Dumper::Dumper($opt));

    my $res = $self->_post( $url => {
        $opt? %$opt : (),
        ApiKey => $self->apiKey,
    });

    $self->_parse_cookie_apikey() unless $self->apiKey;
    if ( ! $res || ! $res->is_success ) {
        Carp::croak "POST failed. status=[", $self->{mech}->status, "] status line=[", $res->status_line, "]";
    }
    
    my $json = from_json( $self->{mech}->content, { utf8 => 0 } );
    $DEBUG && debug("$api returns ", Data::Dumper::Dumper($json));
    $json;
}

sub unread_cnt {
    my ($self) = @_;

    my $res = $self->_post( $urls->{notify} => {
        user => $self->{user}
    });
    my $content = $res->content;
    $DEBUG && debug("content=[$content]");
    my ($cnt) = $content =~ /\|(-?\d+)\|\|/;
    $cnt;
}

sub _post {
    my ($self, $uri, $opt) = @_;

    my $res;
    try {
        $res = $self->{mech}->post( $uri => {
            $opt? %$opt : ()
        });
    } finally {
        $DEBUG && debug("POST response status=[", $self->{mech}->status, "]");
    };
    $res;
}

sub _parse_cookie_apikey {
    my ($self) = @_;
    
    $self->{mech}->cookie_jar->scan( sub {
        my ($key, $val) = @_[1,2];
        if ( $key =~ /reader_sid$/ ) {
            $self->apiKey( $val );

            $DEBUG && debug("apiKey=[$val]");
            return;
        }
    } );
}

sub debug {
    print "[DEBUG] ", @_, "\n" if @_;
}

=head1 AUTHOR

kiririmode, C<< <kiririmode at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-webservice-ldr at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WebService-LDR>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::LDR


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WebService-LDR>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WebService-LDR>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WebService-LDR>

=item * Search CPAN

L<http://search.cpan.org/dist/WebService-LDR/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 kiririmode.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WebService::LDR

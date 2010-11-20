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
Reader, and has the following properties.

=over 4

=item * subscribe_id

=item * ErrorCode

=item * isSuccess

=back

=cut

sub subscribe {
    my ($self, $arg) = @_;

    my $link;
    if ( ref($arg) && ! $arg->isa('URI') ) {
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

=head2 unsubscribe

    my $result = $ldr->unsubscribe($uri) or 
        warn "cannot discover feed on $uri";

Unsubscribes feed on specified URI.  It returns WebService::LDR::Response::Result
on success, and undef on failure of discovering feed on the URI.

Argument can be string URI or subscribe_id.
If a string or C<URI> is passed as a parameter, it executes
C<auto_discovery> to discover its feed, and then unsubscribes the feed.

=cut
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

=head2 get_feed_all

    my @feeds = $ldr->get_feed_all();

Retrieves all feeds you have subscribed.  Each feed is C<WebService::LDR::Response::Feed> class
and has the following properties.

=head3 WebService::LDR::Response::Feed

=over 4

=item * icon 

=item * link 

=item * subscribe_id 

=item * unread_count 

=item * tags 

=item * folder 

=item * rate 

=item * modified_on 

=back

=cut 

sub get_feed_all {
    my ($self) = @_;

    map { WebService::LDR::Response::Feed->new($_) } 
        @{ $self->_request( '/subs' => { unread => 0 } ) };
}

=head2 get_feed_unread

    my @feeds = $ldr->get_feed_unread();

Retrieves unread feeds you have subscribed.  Each feed is C<WebService::LDR::Response::Feed> class.

=cut

sub get_feed_unread {
    my ($self) = @_;

    map { WebService::LDR::Response::Feed->new($_) } 
        @{ $self->_request( '/subs' => { unread => 1 } ) };
}

=head2 get_unread_of

    my $article = $ldr->get_unread_of($arg);

Retrieves unread article on a specified feed.  The argument can be
everything which has subscribe_id property such as C<WebService::LDR::Response::Feed>,
or just a subscribe_id.

This method returns C<WebService::LDR::Response::Article>, which has the followings.

=head3 C<WebService::LDR::Response::Article>

=over 4

=item * subscribe_id 

=item * last_stored_on 

=item * channel

C<WebService::LDR::Response::Channel> class.  It has C<link>, C<icon>, C<description>,
C<image>, C<title>, C<feedlink>, C<subscribers_count>, and C<expires>.

=item * items

Array reference of C<WebService::LDR::Response::Item> class.  It has C<link>, C<enclosure>, C<enclosure_type>,
C<author>, C<body>, C<created_on>, C<modified_on>, C<category>, C<title>, and C<id>.

=back

=cut

sub get_unread_of {
    my ($self, $arg) = @_;

    my $subscribe_id = $self->_subscribe_id($arg);
    WebService::LDR::Response::Article->new(
        $self->_request( '/unread' => { subscribe_id => $subscribe_id } )
    );
}

=head2 get_all_of

    my $article = $ldr->get_all_of($feed, $offset, $limit);

Retrieves all articles on a specified feed.  The C<$feed> can be everything
which has subscribe_id property such as C<WebService::LDR::Response::Article>,
or just a subscribe_id.

C<$offset> and C<$limit> are optional arguments.  C<$offset> is the starting
point of item which is returned from this method.  C<$limit> is the number of
items returned.

An article returned is the class C<WebService::LDR::Response::Article>.

=cut

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

=head2 read

  my $result = $ldr->read($feed);

Makes all items on the C<$feed> read and returns C<WebService::LDR::Response::Result>.
C<$feed> can be everything which has subscribe_id method.

=cut

sub read {
    my ($self, $arg) = @_;

    my $subscribe_id = $self->_subscribe_id($arg);
    WebService::LDR::Response::Result->new(
        $self->_request('/touch_all' => { subscribe_id => $subscribe_id })
    );
}

=head2 set_rate

  my $result = $ldr->set_rate($feed => $rate)

Set the rate of specified C<$feed> to C<$rate> (between 1 and 5).  
C<$feed> can be everything which has C<subscribe_id> method.  

=cut

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

=head2 folders

    my $folder_info = $ldr->folders();

Retrieves folder information on your Livedoor Reader account.  It returns
C<WebService::LDR::Response::Folder> class, which has following methods.

=over 4

=item * name2id

Gets the hash reference which has mapping of folder name and its ID.

=item * names

Gets the array reference, which contents are the folder names.

=item * exists

Return true value if the folder name passed exists.

=back

=cut

sub folders {
    my ($self) = @_;

    WebService::LDR::Response::Folders->new(
        $self->_request('/folders')
    );
}

=head2 make_folder

    $ldr->make_folder($folder_name);

Creates folder on Livedoor Reader.  It returns C<WebService::LDR::Response::Result>.  

=cut

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

=head2 delete_folder

    $ldr->delete_folder($name_or_id);

Deletes folder on Livedoor Reader.  The argument is folder name or its ID to be deleted.
This method also returns C<WebService::LDR::Response::Result>.

=cut

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

=head2 move_folder

    $ldr->move_folder($feed => $folder);

Moves C<$feed> to folder C<$folder>.
This method also returns C<WebService::LDR::Response::Result>.

=cut

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

=head2 get_pin_all

    my @pins = $ldr->get_pin_all();

Retrieves all entries you have pinned on Livedoor Reader.  The entries are returned as
an array of C<WebService::LDR::Response::Pin>, which has following properties.

=over 4

=item * link

=item * created_on

=item * title

=back

=cut

sub get_pin_all {
    my ($self) = @_;

    map { WebService::LDR::Response::Pin->new($_) }
        @{ $self->_request('/pin/all') };
}

=head2 add_pin

    my $result = $ldr->add_pin($link, $title);

Pins specified C<$link> on Livedoor Reader as C<$title>.  C<$link> can be everything
its stringfied values are URI, such as L<URI> class.
This method returns C<WebService::LDR::Response::Result>.

=cut

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

=head2 delete_pin

    my $result = $ldr->delete_pin($link);

Deletes entry of specified C<$link> on Your Livedoor Reader, and returns
C<WebService::LDR::Response::Result>.

=cut

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

=head2 clear_pin

    my $result = $ldr->clear_pin();

Deletes all entries you have pinned, and returns C<WebService::LDR::Response::Result>

=cut

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

=head2 unread_cnt

Returns number of unread entries.

=cut

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
        if ( ! $res ) {
            Carp::croak "POST failed. status=[", $self->{mech}->status, "] res is undefined";
        }
        if ( ! $res->is_success ) {
            Carp::croak "POST failed. status=[", $self->{mech}->status, "] status line=[", $res->status_line, "]";
        }
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

Please report any bugs or feature requests to me via above gmail account or L<github|https://github.com/kiririmode/WebService-LDR>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::LDR

=head1 LICENSE AND COPYRIGHT

Copyright 2010 kiririmode.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WebService::LDR

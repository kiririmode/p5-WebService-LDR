package WebService::LDR::Response;

use warnings;
use strict;
use base qw/Class::Accessor::Fast/;
use URI;
use DateTime;
use Data::Dumper;

sub new {
    my ($class, $h) = @_;

    my $self = bless {}, $class;
    for my $ac ( $class->accessors() ) {
        if ( $ac =~ /link|icon/ ) {
            $self->$ac( URI->new($h->{$ac}) );
        }
        elsif ( $ac =~ /_on$|expires/ ) {
            $self->$ac( DateTime->from_epoch( epoch => $h->{$ac} ));
        }
        elsif ( $ac eq 'channel' ) {
            $self->$ac( WebService::LDR::Response::Channel->new( $h->{$ac} ) );
        }
        elsif ( $ac eq 'items' ) {
            $self->$ac([ 
                map { WebService::LDR::Response::Item->new( $_ ) }
                    @{ $h->{$ac} }
            ]);
        }
        else {
            $self->$ac( $h->{$ac} );
        }
    }
    $self;
};

# ================================================================================
package WebService::LDR::Response::Discovery;
use base qw/WebService::LDR::Response/;
sub accessors {
    qw/link subscribe_id title feedlink subscribers_count/
}
__PACKAGE__->mk_accessors( accessors() );

# ================================================================================
package WebService::LDR::Response::Subscribe;
use base qw/WebService::LDR::Response/;
sub accessors {
    qw/subscribe_id ErrorCode isSuccess/
}
__PACKAGE__->mk_accessors( accessors() );

# ================================================================================
package WebService::LDR::Response::Unsubscribe;
use base qw/WebService::LDR::Response/;
sub accessors { qw/ErrorCode isSuccess/ }
__PACKAGE__->mk_accessors( accessors() );

# ================================================================================
package WebService::LDR::Response::Feed;

use base qw/WebService::LDR::Response/;
sub accessors {
    qw/icon link subscribe_id unread_count tags folder rate modified_on 
       public title subscribers_count feedlink/
}
__PACKAGE__->mk_accessors( accessors() );

# ================================================================================
package WebService::LDR::Response::Article;
use base qw/WebService::LDR::Response/;

# last_stored_on isn't necessary parameter.
sub accessors {
    qw/subscribe_id last_stored_on channel items/
}
__PACKAGE__->mk_accessors( accessors() );

# ================================================================================
package WebService::LDR::Response::Channel;
use base qw/WebService::LDR::Response/;

sub accessors {
    qw/link icon description image title feedlink subscribers_count expires/
}
__PACKAGE__->mk_accessors( accessors() );

# ================================================================================
package WebService::LDR::Response::Item;
use base qw/WebService::LDR::Response/;

sub accessors {
    qw/link enclosure enclosure_type author body created_on modified_on category title id/
}
__PACKAGE__->mk_accessors( accessors() );

1;

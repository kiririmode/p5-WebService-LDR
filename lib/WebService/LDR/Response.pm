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
        elsif ( $ac eq 'modified_on' ) {
            $self->$ac( DateTime->from_epoch( epoch => $h->{$ac} ));
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

1;


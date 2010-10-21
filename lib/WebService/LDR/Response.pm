package WebService::LDR::Response;

use warnings;
use strict;
use base qw/Class::Accessor::Fast/;
use URI;
use Carp qw//;


# ================================================================================
package WebService::LDR::Response::Discovery;
use base qw/Class::Accessor::Fast/;
our @accessors = qw/link subscribe_id title feedlink subscribers_count/;
__PACKAGE__->mk_accessors( @accessors );

sub new {
    my ($class, $h) = @_;

    my $self = bless {}, shift;
    for my $ac (@accessors) {
        if ( $ac =~ /link/ ) {
            $self->$ac( URI->new($h->{$ac}) );
        }
        else {
            $self->$ac( $h->{$ac} );
        }
    }
    $self;
};

# ================================================================================
package WebService::LDR::Response::Subscribe;
use base qw/Class::Accessor::Fast/;
our @accessors = qw/subscribe_id ErrorCode isSuccess/;
__PACKAGE__->mk_accessors( @accessors );

sub new {
    my ($class, $h) = @_;
    my $self = bless {}, shift;
    for my $ac (@accessors) {
        $self->$ac( $h->{$ac} );
    }
    $self;
}




1;

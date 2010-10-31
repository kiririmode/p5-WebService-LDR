#!perl -T
use strict;
use warnings;
use Test::More;
use Test::Exception;
use Scalar::Util qw/looks_like_number/;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

my $cnt = 1;
SKIP: {
    skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 6
        unless ($ENV{LDR_TEST_ID} and $ENV{LDR_TEST_PASS});

    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );

    isa_ok( $ldr, 'WebService::LDR' );         $cnt++;
    lives_ok { $ldr->login } 'login success';  $cnt++;
    can_ok( $ldr, qw/get_pin_all/ );           $cnt++;

    my @pins = $ldr->get_pin_all();
    if ( @pins ) {
        my $pin = shift @pins;
        isa_ok( $pin, 'WebService::LDR::Response::Pin' ); $cnt++;
        can_ok( $pin, qw/link created_on title/ );        $cnt++;
        isa_ok( $pin->link, 'URI' );                      $cnt++;
        isa_ok( $pin->created_on, 'DateTime' );           $cnt++;
    }
}

done_testing($cnt);

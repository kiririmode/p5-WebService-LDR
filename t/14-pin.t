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
    unless ($ENV{LDR_TEST_ID} and $ENV{LDR_TEST_PASS}) {
        $cnt = 16;
        skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 15;
    }

    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );

    isa_ok( $ldr, 'WebService::LDR' );         $cnt++;
    lives_ok { $ldr->login } 'login success';  $cnt++;
    can_ok( $ldr, qw/add_pin get_pin_all/ );           $cnt++;

    my $uri   = 'http://d.hatena.ne.jp/kiririmode';
    my $title = 'test title';
    my $res1 = $ldr->add_pin( $uri => $title );
    isa_ok( $res1, 'WebService::LDR::Response::Result' ); $cnt++;

    my @pins1 = $ldr->get_pin_all();
    my $pin_number = @pins1;

    my $pin = shift @pins1;
    isa_ok( $pin, 'WebService::LDR::Response::Pin' ); $cnt++;
    can_ok( $pin, qw/link created_on title/ );        $cnt++;
    isa_ok( $pin->link, 'URI' );                      $cnt++;
    isa_ok( $pin->created_on, 'DateTime' );           $cnt++;

    cmp_ok( $pin->link->as_string, 'eq', $uri, 'same URI' ); $cnt++;
    cmp_ok( $pin->title, 'eq', $title, 'same title' );       $cnt++;

    my $res2 = $ldr->delete_pin($uri);
    isa_ok( $res1, 'WebService::LDR::Response::Result' ); $cnt++;

    my @pins2 = $ldr->get_pin_all();
    cmp_ok( $pin_number - 1, '==', scalar(@pins2), 'pin number after deletion' ); $cnt++;

    my $res3 = $ldr->clear_pin();
    isa_ok( $res3, 'WebService::LDR::Response::Result' ); $cnt++;

    my @pins3 = $ldr->get_pin_all();
    cmp_ok(scalar(@pins3), '==', 0, 'pin number after clear'); $cnt++;

    for my $pin (@pins2) {
        $ldr->add_pin( $pin->link, $pin->title );
    }
}

done_testing($cnt);

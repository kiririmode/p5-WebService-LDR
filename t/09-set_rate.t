#!perl -T
use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use Scalar::Util qw/looks_like_number/;

BEGIN {
    use_ok( 'WebService::LDR' ) || print "Bail out!
";
}

SKIP: {
    skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 13
        unless ($ENV{LDR_TEST_ID} and $ENV{LDR_TEST_PASS});

    my $rss = 'http://d.hatena.ne.jp/kiririmode/rss';
    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    lives_ok { $ldr->login } 'login success';
    can_ok( $ldr, qw/set_rate/ );

    $ldr->unsubscribe($rss);
    my $subscribed = $ldr->subscribe($rss);
    throws_ok { $ldr->set_rate($subscribed)        } qr/rate is undef/;
    throws_ok { $ldr->set_rate($subscribed => 'a') } qr/rate is not a number/;
    my $res = $ldr->set_rate($subscribed => 5);
    isa_ok($res, 'WebService::LDR::Response::Result');

    $ldr->unsubscribe( $subscribed );
}

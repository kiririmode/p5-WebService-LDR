#!perl -T
use strict;
use warnings;
use Test::More tests => 14;
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

    can_ok( $ldr, qw/subscribe unsubscribe/ );
    my @links = $ldr->auto_discovery( 'http://d.hatena.ne.jp/kiririmode/rss' );
    cmp_ok( scalar @links, '>', 0, 'auto_discovery returns valid feed info' );
    $ldr->unsubscribe( $links[0]->link );

    my $ret = $ldr->subscribe($rss);
    isa_ok( $ret, 'WebService::LDR::Response::Result' );
    can_ok( $ret, qw/subscribe_id ErrorCode isSuccess/ );
    ok( $ret->isSuccess, 'subscribe success' );
    ok( looks_like_number( $ret->subscribe_id ), 'subscribe_id is a number' );

    my $id  = $ret->subscribe_id;
    my $ret2 = $ldr->subscribe($rss);
    cmp_ok( $ret2->isSuccess, '==', 0, 'duplicate subscription is prohibited' );
    ok( $ret2->ErrorCode, 'duplicate subscription returns errorcode' );

    my $ret3 = $ldr->unsubscribe($links[0]->link);
    isa_ok( $ret3, 'WebService::LDR::Response::Unsubscribe' );
    can_ok( $ret, qw/ErrorCode isSuccess/ );
    ok( $ret3->isSuccess, 'unsubscribe sccess' );
}

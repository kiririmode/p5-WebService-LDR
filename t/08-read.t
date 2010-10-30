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
    can_ok( $ldr, qw/read/ );

    $ldr->unsubscribe($rss);
    my $subscribed = $ldr->subscribe($rss);
    my $read       = $ldr->read( $subscribed );
    isa_ok($read, 'WebService::LDR::Response::Result');

    my $article = $ldr->get_unread_of( $subscribed );
    isa_ok( $article, 'WebService::LDR::Response::Article' );
    cmp_ok( scalar @{$article->items}, '==', 0, 'unread item is 0' );
    
    $ldr->unsubscribe( $subscribed );
}

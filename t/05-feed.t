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
        $cnt += 16;
        skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 16;
    }

    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    lives_ok { $ldr->login } 'login success';
    $cnt += 2;

    can_ok( $ldr, qw/get_feed_all get_feed_unread/ );
    $cnt++;

    my @feeds = $ldr->get_feed_all();
    if ( @feeds ) {
        my $feed = shift @feeds;
        isa_ok( $feed, 'WebService::LDR::Response::Feed' );
        can_ok( $feed, qw/icon link subscribe_id unread_count tags folder 
                          rate modified_on public title subscribers_count feedlink/ );
        isa_ok( $feed->icon, 'URI::http' );
        isa_ok( $feed->link, 'URI::http' );
        ok( looks_like_number($feed->subscribe_id), 'subscribe_id is a number' );
        ok( looks_like_number($feed->unread_count), 'unread_count is a number' );
        isa_ok( $feed->tags, 'ARRAY' );
        # $feed->folder
        ok( looks_like_number($feed->rate), 'rate is a number' );
        ok( looks_like_number($feed->public), 'public is a number' );
        isa_ok( $feed->modified_on, 'DateTime' );
        ok( $feed->title, 'title is not null' );
        ok( looks_like_number($feed->subscribers_count), 'subscribers_count is a number' );
        isa_ok( $feed->feedlink, 'URI::http' );
        $cnt += 13;
    }
}

done_testing( $cnt );

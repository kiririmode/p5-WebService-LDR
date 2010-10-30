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
        $cnt += 27;
        skip "LDR_TEST_ID and/or LDR_TEST_PASS is not set", 27;
    }

    my $ldr = WebService::LDR->new( 
        user => $ENV{LDR_TEST_ID}, 
        pass => $ENV{LDR_TEST_PASS},
    );
    isa_ok( $ldr, 'WebService::LDR' );
    lives_ok { $ldr->login } 'login success';
    $cnt += 2;

    can_ok( $ldr, qw/get_unread_of/ );
    $cnt++;

    my @feeds = $ldr->get_feed_unread();
    if ( @feeds ) {
        my $feed = shift @feeds;
        isa_ok( $feed, 'WebService::LDR::Response::Feed' );
        my $unread = $ldr->get_unread_of( $feed );

        isa_ok( $unread, 'WebService::LDR::Response::Article' );
        can_ok( $unread, qw/subscribe_id last_stored_on channel items/ );
        ok( looks_like_number( $unread->subscribe_id ), 'subscribe_id is a number' );
        isa_ok( $unread->channel, 'WebService::LDR::Response::Channel' );
        my $channel = $unread->channel;
        can_ok( $channel, qw/link icon description image title feedlink subscribers_count expires/ );
        isa_ok( $channel->link, 'URI' );
        isa_ok( $channel->icon, 'URI' );
        ok( $channel->description, 'description is not null' );
        ok( $channel->title, 'title is not null' );
        isa_ok( $channel->feedlink, 'URI' );
        ok( looks_like_number( $channel->subscribers_count ), 'subscribers_count is a number' );
        isa_ok( $channel->expires, 'DateTime' );

        isa_ok( $unread->items, 'ARRAY' );
        $cnt += 14;

        if ( @{ $unread->items } ) {
            my $item = shift @{ $unread->items };
            isa_ok( $item, 'WebService::LDR::Response::Item' );
            can_ok( $item, qw/link enclosure enclosure_type author body created_on modified_on category title id/ );
            isa_ok( $item->link, 'URI' );
            ok( $item->author, 'author is not null' );
            ok( $item->body, 'body is not null' );
            isa_ok( $item->created_on, 'DateTime' );
            isa_ok( $item->modified_on, 'DateTime' );
            ok( $item->category, 'category is not null' );
            ok( $item->title, 'title is not null' );
            ok( looks_like_number( $item->id ), 'id is a number' );
            $cnt += 10;
        }

    }
}

done_testing( $cnt );

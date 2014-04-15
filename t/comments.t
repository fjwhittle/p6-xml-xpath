#!/usr/bin/env perl6

use XML::XPath;
use Test;

plan 5;

my $xp = XML::XPath.new;

my @r = $xp.evaluate(q{ "foo" (: This is a comment :), "bar" });

is @r, <foo bar>, 'Embedded comment';

@r = $xp.evaluate(q{(: Comment start :) "foo", (: Comment middle :) "bar" (: Comment end :)});

is @r, <foo bar>, 'Surrounding comments';

@r = $xp.evaluate(q{ "foo" (: This is a (: nested comment :) , "bar" :)});

is @r, <foo>, 'Nested comment';

@r = $xp.evaluate(q{ ( "foo" (: ) , "bar" :), "baz" ) });

is @r, <foo baz>, 'Comment with unbalanced content';

@r = $xp.evaluate(q{ "foo", "(: bar :) :)" });

is @r, @('foo', '(: bar :) :)'), 'Comment in quotes';
#!/usr/bin/env perl6

use XML::XPath;
use Test;

plan 7;

my $xp = XML::XPath.new;

my @r = $xp.evaluate(q{ "foo" and "bar" });

is @r[0], 'bar', 'And, positive LHS';

@r = $xp.evaluate(q{ "foo" or "bar" });

is @r[0], 'foo', 'Or, positive LHS';

@r = $xp.evaluate(q{ "" and "bar" });

ok !@r[0], 'And, negative LHS';

@r = $xp.evaluate(q{ "" or "bar" });

is @r[0], 'bar', 'Or, negative LHS';

@r = $xp.evaluate(q{ "foo" and "" or "baz" });

is @r[0], 'baz', 'Precedence, or following and';

@r = $xp.evaluate(q{ "foo" or "bar" and "baz" });

is @r[0], 'foo', 'Precedence, and following or, positive LHS';

@r = $xp.evaluate(q{ "" or "bar" and "baz" });

is @r[0], 'baz', 'Precedence, and following or, negative LHS';

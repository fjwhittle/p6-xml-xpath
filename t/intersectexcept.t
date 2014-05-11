#!/usr/bin/env perl6

use XML::XPath;
use Test;

plan 2;

my $xp = XML::XPath.new;

my @r = $xp.evaluate('(1 to 10) intersect (5 to 15)');

is @r, (5..10), 'intersect';

@r = $xp.evaluate('(1 to 10) except (3 to 7)');

is @r, (1..2, 8..10), 'except';

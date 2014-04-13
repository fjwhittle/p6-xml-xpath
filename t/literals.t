#!/usr/bin/env perl6

use XML::XPath;
use Test;

plan 4;

my $xp = XML::XPath.new;

my @l = $xp.evaluate(q{ 'foo''s bar', 2, .6, 7.2e-4 });

is @l[0], q{foo's bar}, 'String literal with embedded quotes';

is @l[1], 2, 'Integer literal';

is @l[2], 0.6, 'Float literal';

is @l[3], 0.00072, 'Exponent literal';

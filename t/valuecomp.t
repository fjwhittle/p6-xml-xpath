#!/usr/bin/env perl6

use XML::XPath;
use Test;

plan 6;

my $xp = XML::XPath.new;

# Value Comparisons

my @r = $xp.evaluate(q{1 lt 2, 1 lt 1, 2 lt 1});

is @r, (True, False, False), 'Value comparison lt';

@r = $xp.evaluate(q{1 le 2, 2 le 2, 2 le 1});

is @r, (True, True, False), 'Value comparison le';

@r = $xp.evaluate(q{1 gt 2, 1 gt 1, 2 gt 1});

is @r, (False, False, True), 'Value comparison gt';

@r = $xp.evaluate(q{1 ge 2, 2 ge 2, 2 ge 1});

is @r, (False, True, True), 'Value comparison ge';

@r = $xp.evaluate(q{1 eq 2, 1 eq 1, 2 eq 1});

is @r, (False, True, False), 'Value comparison eq';

@r = $xp.evaluate(q{1 ne 2, 2 ne 2, 2 ne 1});

is @r, (True, False, True), 'Value comparison ne';

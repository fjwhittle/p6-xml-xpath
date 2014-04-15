use v6;

class XML::XPath;

use XML::XPath::Grammar;

has $!context = Nil; # Holds the current evaluation context;
has Str $!sep = '';

my %expr_cache = ();

method cache(XML::XPath:T:) {
    %expr_cache;
}

method evaluate(Str $expr) {
    my $match = %expr_cache{$expr} //= XML::XPath::Grammar.parse($expr);

    return self.Expr($match<Expr>);
}

method !Something(Match $match) {
    my $step = $match.pairs[0];

    if my $subref = self.can($step.key) {
	return $subref[0](self, $step.value);
    }

    die($step.key ~ " not supported!");
}

method Expr(Match $match) {
    my @expr = map -> $es { self.ExprSingle($es); }, @($match<ExprSingle>);

    return @expr;
}

method ExprSingle(Match $match) {
    return self!Something($match);
}

method OrExpr(Match $match) {
    my $return;
    for @($match<AndExpr>) -> $submatch {
	return $return if $return = self.AndExpr($submatch);
    }
    return $return;
}

method AndExpr(Match $match) {
    my $return;
    for @($match<ComparisonExpr>) -> $submatch {
	return $return if !($return = self.ComparisonExpr($submatch));
    }
    return $return;
}

method ComparisonExpr(Match $match) {
    if $match<RangeExpr>.elems > 1 {
	return self.ValueComp($match) if $match<ValueComp>:exists;
	return self.GeneralComp($match) if $match<GeneralComp>:exists;
	return self.NodeComp($match) if $match<NodeComp>:exists;
    }
    return self.RangeExpr($match<RangeExpr>[0]);
}

method ValueComp(Match $match) {
    
}

method RangeExpr(Match $match) {
    if $match<AdditiveExpr>.elems == 2 {
	# Eagerify this because when do we want to deal with lazy lists?
	return @(self.AdditiveExpr($match<AdditiveExpr>[0]) .. self.AdditiveExpr($match<AdditiveExpr>[1]));
    } else {
	return self.AdditiveExpr($match<AdditiveExpr>[0]);
    }
}

method AdditiveExpr(Match $match) {
    my $value = self.MultiplicativeExpr($match<MultiplicativeExpr>[0]);
    
    for @($match<MultiplicativeExpr>[1..*]) Z @($match<op>) -> $next, $op {
	my $nextval = self.MultiplicativeExpr($next);
	
	if $value.does(Str) || $nextval.does(Str) {
	    given ($op ~ '') {
		$value ~= $nextval when '+';
		$value ~~ s/$nextval// when '-';
	    }
	} else {
	    given ($op ~ '') {
		$value += $nextval when '+';
		$value -= $nextval when '-';
	    }
        }
    }

    return $value;
}

method MultiplicativeExpr(Match $match) {
    my $value = self.UnionExpr($match<UnionExpr>[0]);

    for @($match<UnionExpr>[1..*]) Z @($match<op>) -> $next, $op {
	my $nextval = self.UnionExpr($next);

	given ($op ~ '') {
	    $value *= $nextval when '*';
	    $value /= $nextval when 'div';
	    $value = Int($value) div Int($nextval) when 'idiv';
	    $value %= $nextval when 'mod';
	}
    }

    return $value;
}

method UnionExpr(Match $match) {
    my $value = [(|)] map { self.IntersectExceptExpr($_) },  @($match<IntersectExceptExpr>);
    
    return $value.end ?? $value.keys !! $value.keys[0];
}

method IntersectExceptExpr(Match $match_in) {
    my $match = %(
	op => $match_in<op>,
	UnaryExpr => ($_<TreatExpr><CastableExpr><CastExpr><UnaryExpr> for @($match_in<InstanceofExpr>)),
    );
	
    my $value = self.UnaryExpr($match<UnaryExpr>[0]);
    
    if $match<UnaryExpr>.elems > 1 {
	$value.isa(List) or $value = [ $value ];

	for @( $match<UnaryExpr>[1..*] ) Z @( $match<op> ) -> $next, $op {
	    my $nextval = self.UnaryExpr($next);
	    given $op {
		when 'intersect' {
		    $value = $value (&) $nextval;
		}
		when 'except' {
		    $value = $value (-) $nextval;
		}
	    }

	}

	$value = $value.keys;
    }
	
    return $value;
}

method UnaryExpr(Match $match) {
    my $neg = 0;
    $_ eq '-' and $neg ^= 1 for @($match<op>);

    my $value = self.PathExpr($match<ValueExpr>);

    $value = -$value if $neg && $value.does(Numeric);
    
    return $value;
}

method PathExpr(Match $match) {
    temp $!sep;
    temp $!context;
    for 0..$match<sep>.end -> Int $i {
	$!sep = '' ~ $match<sep>[$i];
	$!context = self.StepExpr($match<StepExpr>[$i]);
    }
    return $!context;
}

method StepExpr(Match $match) {
    return self!Something($match);
}

method PrimaryExpr(Match $match) {
    return self!Something($match);
}

method FilterExpr(Match $match) {
    temp $!context = self.PrimaryExpr($match<PrimaryExpr>);
    for @($match<Predicate>) -> $pred {
	return Nil unless self.Expr($pred<Expr>); 
    }
    return $!context;
}

method Literal(Match $match) {
    $match<NumericLiteral>:exists and return $match<NumericLiteral> + 0;
    my $val = $match<StringLiteral> ~ '';
    my $q = $match<StringLiteral><q> ~ '';
    $val ~~ s:g/$q**2/$q/;
    return $val;
}

method ParenthesizedExpr(Match $match) {
    return self.Expr($match<Expr>);
}

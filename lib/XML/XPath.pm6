use v6;

class XML::XPath;

use XML::XPath::Grammar;

has $!context; # Holds the current evaluation context;
has Str $!sep = '';

my %expr_cache = ();

method cache(XML::XPath:T:) {
    %expr_cache;
}

method new ($init_context = Nil){
    self.bless(:context($init_context));
}

submethod BUILD (:$!context) { }

multi method evaluate(XML::XPath:D: Str $expr, $context = Nil) {
    my $match = %expr_cache{$expr} //= XML::XPath::Grammar.parse($expr, :rule<Expr>);

    $context and temp $!context = $context;

    $match.isa(Match:D) and return self.Expr($match);

    warn 'Parse error';

    return Nil;
}

multi method evaluate(XML::XPath:U: Str $expr, $context = Nil) {
    return self.new.evaluate($expr, $context);
}

method !Something(Match $match) {
    my $step = $match.pairs[0];

    if my $subref = self.can($step.key) {
	return $subref[0](self, $step.value);
    }

    die "{$step.key} not supported!";
}

method Expr(Match $match) {
    my @expr = $match<ExprSingle>.map: -> $es { @(self.ExprSingle($es)); };

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
	my Code $opc;
	if my $op = $match<ValueComp> {
	    given $op {
		$opc = &infix:<eq> when 'eq';
		$opc = &infix:<ne> when 'ne';
		$opc = &infix:<lt> when 'lt';
		$opc = &infix:<le> when 'le';
		$opc = &infix:<gt> when 'gt';
		$opc = &infix:<ge> when 'ge';
	    }
	    return $opc(|$match<RangeExpr>[0,1].map: { self.RangeExpr($_) });
	} elsif $op = $match<GeneralComp> {
	    # XPath's non-equality rule for lists differs from Perl's junctions:
	    # Use the difference of sets.
	    return ?[⊖]($match<RangeExpr>[0,1].map: { my $r = self.RangeExpr($_) }) if $op eq '!=';
	    given $op {
		$opc = &infix:<eq> when '=';
		$opc = &infix:<lt> when '<';
		$opc = &infix:<le> when '<=';
		$opc = &infix:<gt> when '>';
		$opc = &infix:<ge> when '>=';
	    }
	    return ?$opc(|$match<RangeExpr>[0,1].map: { self.RangeExpr($_).any });
	}
	return self.NodeComp($match) if $match<NodeComp>;
    }
    return self.RangeExpr($match<RangeExpr>[0]);
}

method RangeExpr(Match $match) {
    if $match<AdditiveExpr>.elems == 2 {
	# Eagerify this because when do we want to deal with lazy lists?
	return self.AdditiveExpr($match<AdditiveExpr>[0]) .. self.AdditiveExpr($match<AdditiveExpr>[1]);
    } else {
	return self.AdditiveExpr($match<AdditiveExpr>[0]);
    }
}

method AdditiveExpr(Match $match) {
    my $value = self.MultiplicativeExpr($match<MultiplicativeExpr>[0]);

    for @($match<MultiplicativeExpr>[1..*]) Z @($match<op>) -> $next, $op {
	my $nextval = self.MultiplicativeExpr($next);

	if $value.does(Str) || $nextval.does(Str) {
	    given ($op) {
		$value ~= $nextval when '+';
		$value ~~ s/$nextval// when '-';
	    }
	} else {
	    given ($op) {
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

	given ($op) {
	    $value *= $nextval when '*';
	    $value /= $nextval when 'div';
	    $value = Int($value) div Int($nextval) when 'idiv';
	    $value %= $nextval when 'mod';
	}
    }

    return $value;
}

method UnionExpr(Match $match) {
    my $value = [∪] @($match<IntersectExceptExpr>).map: { self.IntersectExceptExpr($_) };

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
		    $value = $value ∩ $nextval;
		}
		when 'except' {
		    $value = $value ∖ $nextval;
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
    if $match<root>:exists {
	$!context.isa('XML::Document') and return $!context.root;
	$!context.isa('XML::Node') and return $!context.ownerDocument.root;
	die 'Attempt to match root node with no XML context';
    }

    if ($!context) {
	$!context = $!context.ownerDocument.root if $match<sep>[0] eq '/' && !$!context.isa('XML::Document');
	$!context = $!context.root if $!context.isa('XML::Document');
    }

    for @( $match<sep> ) Z @( $match<StepExpr> ) -> $sep, $n {
	$!sep = ~ $sep;
	$!context = self.StepExpr($n);
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
    my $val = ~ $match<StringLiteral>;
    my $q = ~ $match<StringLiteral><q>;
    $val ~~ s:g/$q**2/$q/;
    return $val;
}

method ParenthesizedExpr(Match $match) {
    return self.Expr($match<Expr>);
}

method AxisStep(Match $match) {
    my ($axis, $nodetest);
    if $match<AbbrevForwardStep> {
	$axis = $match<AbbrevForwardStep><attr> eq '@' ?? 'attribute' !! ($!sep eq '//') ?? 'descendant' !! 'child';
	$nodetest = $match<AbbrevForwardStep><NodeTest>;
    } elsif $match<AbbrevReverseStep> {
	$axis = 'parent'; # I don't think //.. means ancestor, better check.
	$nodetest = '*';
    } else {
	$axis = ~ $match<Axis>;
	$nodetest = $match<NodeTest>;
    }

    set(@( $!context ).map: {
	temp $!context = $_;

	my @nodes = self.Axis($axis, $nodetest);

	for @($match<Predicate>) -> $pred {
	    @nodes .= grep: {
		temp $!context = $_;
		? self.Expr($pred<Expr>).shift; # See http://www.w3.org/TR/xpath20/#dt-ebv
	    };
	}
	@nodes;

    }).keys;
}

multi method Axis('child', $nodetest) {
    $!context.nodes.grep: { temp $!context = $_; self.NodeTest($nodetest); };
}

multi method Axis('descendant', $nodetest --> Array) {
    $!context.can('nodes') or return;
    my @nodes = $!context.nodes;
    my @dnodes;

    for @nodes.grep: { $_.can('nodes') && $_.nodes } -> $node {
	temp $!context = $node;
	@dnodes.push: self.Axis('descendant', $nodetest);
    }
    @dnodes.unshift: @nodes.grep: { temp $!context = $_; self.NodeTest($nodetest); };
}

multi method Axis('parent', $nodetest) {
    $!context.can('parent') or return;
    temp $!context = $!context.parent;
    self.NodeTest($nodetest);
}

multi method Axis('attribute', $nodetest) {
    $nodetest<NameTest> or fail 'Only Name tests supported for attributes';
    $!context.can('attribs') && $!context.attribs{$nodetest.Str} or ();
}

multi method Axis(Str $unsupported, $nodetest) {
    fail "{$unsupported} axis is unsupported";
}

multi method NodeTest('*') {
    $!context;
}

multi method NodeTest(Match $match) {
    #TODO: Namespace handling
    $match<NameTest> and return self.NameTest($match<NameTest>);
    ...;
}

method NameTest(Match $match) {
    #TODO: Namespace handling
    if $match<Wildcard> && $match<Wildcard> eq '*' or
      $!context.can('name') && $!context.name eq $match<QName><LocalPart> {
	return $!context;
    } else {
	Nil;
    }
}

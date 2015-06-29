use v6;
use XML;

unit class XML::XPath::Actions;

method Expr ($/) {
  $/.make: $<ExprSingle>».made;
}

method ExprSingle ($/) {
  $/.make: $<OrExpr>.made;
}

method ForExpr ($/) { ... };

method SimpleForClause ($/) { ... };

method QuantifiedExpr ($/) { ... };

method IfExpr ($/) { ... };

method OrExpr ($/) {
  if $<AndExpr>.end {
    $/.make: -> $ctx {
      my $r;
      for @($<AndExpr>) -> $submatch {
	$r = $submatch.made.($ctx) and last;
      }
      $r;
    }
  } else {
    $/.make: $<AndExpr>[0].made;
  }
}

method AndExpr ($/) {
  if $<ComparisonExpr>.end {
    $/.make: -> $ctx {
      my $r;
      for @($<ComparisonExpr>) -> $submatch {
	$r = $submatch.made.($ctx) or last;
      }
      $r;
    }
  } else {
    $/.make: $<ComparisonExpr>[0].made;
  }
}

method ComparisonExpr ($/) {
  if $<RangeExpr>.end {
    my $range_expr = $<RangeExpr>».made;

    my Code $opc;
    if my $op = ~$<ValueComp> {
      $/.make: sub ($ctx) {
	given $op.lc {
	  $opc = &infix:<eq> when 'eq';
	  $opc = &infix:<ne> when 'ne';
	  $opc = &infix:<lt> when 'lt';
	  $opc = &infix:<le> when 'le';
	  $opc = &infix:<gt> when 'gt';
	  $opc = &infix:<ge> when 'ge';
	}
	return $opc(|$range_expr».($ctx));
      }
    } elsif $op = ~$<GeneralComp> {
      $/.make: sub ($ctx) {
	# XPath's non-equality rule for lists differs from Perl's junctions:
	# Use the difference of sets.
	return ?[⊖](| $range_expr.map: { [ .($ctx) ] }) if $op eq '!=';
	given $op {
	  $opc = &infix:<eq> when '=';
	  $opc = &infix:<lt> when '<';
	  $opc = &infix:<le> when '<=';
	  $opc = &infix:<gt> when '>';
	  $opc = &infix:<ge> when '>=';
	}
	return ?$opc(| $range_expr.map: { .($ctx).any });
      }
    } elsif $<NodeComp> {
      $/.make: $<NodeComp>.made;
    }
  } else {
    $/.make: $<RangeExpr>[0].made;
  }
}


method RangeExpr ($/) {
  if $<AdditiveExpr>.end {
    my ($from_expr, $to_expr) = $<AdditiveExpr>».made;
    $/.make: -> $ctx { $from_expr.($ctx) .. $to_expr.($ctx) };
  } else {
    $/.make: $<AdditiveExpr>[0].made;
  }
}

method AdditiveExpr ($/) {
  if $<MultiplicativeExpr>.end {
    my @multi_expr = $<MultiplicativeExpr>».made;
    $/.make: -> $ctx {
      my $value = @multi_expr.shift.($ctx);
      for @(@multi_expr».($ctx)) Z @($<op>) -> [$next, $op] {
	if $value.does(Str) || $next.does(Str) {
	  given $op {
	    $value ~= $next when '+';
	    $value ~~ s/$next// when '-';
	  }
	} else {
	  given $op {
	    $value += $next when '+';
	    $value -= $next when '-';
	  }
	}
      }

      $value;
    };
  } else {
    $/.make: $<MultiplicativeExpr>[0].made;
  }
}

method MultiplicativeExpr ($/) {
  if $<UnionExpr>.end {
    my @union_expr = $<UnionExpr>».made;
    $/.make: -> $ctx {
      my $value = @union_expr.shift.($ctx);

      for @(@union_expr».($ctx)) Z @($<op>) -> [$next, $op] {
	given ($op) {
	  $value *= $next when '*';
	  $value /= $next when 'div';
	  $value = Int($value) div Int($next) when 'idiv';
	  $value %= $next when 'mod';
	}
      }

      $value;
    }
  } else {
    $/.make: $<UnionExpr>[0].made;
  }
}

my %so-cache; # Temporize per call to avoid caching old trees.

sub get-source-order(XML::Node $n) {
  %so-cache{$n} //= $n.parent ?? (get-source-order($n.parent), $n.parent.nodes.grep-index($n)) !! ();
}

method UnionExpr ($/) {
  if $<IntersectExceptExpr>.end {
    $/.make: -> $ctx {
      temp %so-cache;
      ([∪] $<IntersectExceptExpr>».made».($ctx)).list.sort: { get-source-order($^a) cmp get-source-order($^b) };
    }
  } else {
    $/.make: $<IntersectExceptExpr>[0].made;
  }
}

method IntersectExceptExpr ($/) {
  if $<InstanceofExpr>.end {
    my @submatch = $<InstanceofExpr>».made;
    my @opl = $<op>.map: ~*;
    $/.make: -> $ctx {
      my $value = @submatch.shift.($ctx);
      my $orig = $value;
      for @submatch Z @opl -> [$next, $op] {
	given $op {
	  when 'intersect' {
	    $value ∩= $next.($ctx);
	  }
	  when 'except' {
	    $value ∖= $next.($ctx);
	  }
	}
      }
      temp %so-cache;
      $value.list.sort: { get-source-order($^a) cmp get-source-order($^b) };
    };
  } else {
    $/.make: $<InstanceofExpr>[0].made;
  }
}

method InstanceofExpr ($/) {
    if $<SequenceType>:exists {
	...
    } else {
	$/.make: $<TreatExpr>.made;
    }
}

method TreatExpr ($/) {
    if $<SequenceType>:exists {
	...
    } else {
	$/.make: $<CastableExpr>.made;
    }
}

method CastableExpr ($/) {
    if $<SingleType>:exists {
	...
    } else {
	$/.make: $<CastExpr>.made;
    }
}

method CastExpr ($/) {
    if $<SingleType>:exists {
	...
    } else {
	$/.make: $<UnaryExpr>.made;
    }
}

method UnaryExpr ($/) {
  $/.make: $<op> eq '-' ?? -> $ctx { - $<ValueExpr>.made.($ctx) } !! $<ValueExpr>.made;
}

# SKIPPED: GeneralComp ValueComp

method NodeComp ($/) { ... }

method PathExpr ($/) {
  if $<root>:exists {
    $/.make: -> $ctx {
      if $ctx.isa('XML::Document') {
	$ctx.root;
      } elsif $ctx.isa('XML::Node') {
	$ctx.ownerDocument.root;
      } else {
	die 'Attempt to match root node with no XML context';
      }
    }
  } else {
    my @sep = $<sep>.map: ~*;
    my @StepExpr = $<StepExpr>».made;
    my @AxisStep = $<StepExpr>.map: { ?.<AxisStep> };
    $/.make: -> $ctx {
      my $context = $ctx;
      for @sep Z @StepExpr Z @AxisStep -> [$sep, $expr, $axis] {
	if $axis {
	  $context = $expr($context, $sep);
	} else {
	  $context = $expr($context);
	}
      }
      @$context.flat.end ?? @$context.flat !! $context[0];
    }
  }
}

method StepExpr ($/) {
  $/.make: $<FilterExpr>.made || $<AxisStep>.made;
}

method AxisStep($/) {
  my ($axis, $nodetest, $axis_ast);
  if $<AbbrevForwardStep> {
    $axis = ($<AbbrevForwardStep><attr> eq '@') ?? 'attribute' !! 'child';
    $nodetest = $<AbbrevForwardStep><NodeTest>.made;
    $axis_ast = -> $ctx, $sep {
      $sep eq '//' and $axis eq 'child' and $axis = 'descendant';
      testAxis($axis, $nodetest, $ctx);
    }
  } elsif $<AbbrevReverseStep> {
    $axis_ast = -> $ctx, $sep {
      $axis = 'parent';
      $nodetest = &matchany;
      testAxis($axis, $nodetest, $ctx);
    }
  } else {
    $nodetest = $<NodeTest>.made;
    $axis = ~$<Axis>;
    $axis_ast = -> $ctx, $sep {
      testAxis($axis, $nodetest, $ctx);
    }
  }

  if ($<Predicate>) {
    my $pct_ast = $<Predicate>».made;
    $/.make: -> $ctx, $sep {
      $axis_ast($ctx, $sep).grep: -> $subctx {
	[&&] $pct_ast».($subctx);
      }
    }
  } else {
    $/.make: $axis_ast;
  }
}

# SKIPPED: Axis AbbrevForwardStep AbbrevReverseStep

method NodeTest ($/) {
  $/.make: $<KindTest>.made || $<NameTest>.made;
}

method NameTest ($/) {
  my ($wildcard, $prefix, $lname) = ~($<Wildcard> // ''), ~($<QName><Prefix> // ''), ~($<QName><LocalPart> // '');
  if $wildcard && $wildcard eq '*' {
    $/.make: -> $ctx { $ctx }
  } elsif $prefix {
    $/.make: -> $ctx { ... }
  } else {
    $/.make: -> $ctx {
      if $ctx.isa('Hash') && ($ctx{$lname}:exists) {
	$ctx{$lname};
      } elsif $ctx.can('name') && $ctx.name eq $lname {
	$ctx;
      } else {
	Nil;
      }
    };
  }
}

# SKIPPED: Wildcard

method FilterExpr ($/) {
  my $primary_expr = $<PrimaryExpr>.made;
  if $<Predicate> {
    my $predicate = $<Predicate>».made;
    $/.make: -> $ctx {
      $primary_expr.($ctx).grep: -> $subctx {
	so [&&] $predicate».($subctx);
      }
    }
  } else {
    $/.make: $primary_expr;
  }
}

method Predicate ($/) {
  $/.make: $<Expr>.made;
}

method PrimaryExpr ($/) {
  $/.make: $<Literal>.made || $<VarName>.made || $<ParenthesizedExpr>.made
    || $<ContextItemExpr>.made || $<FunctionCall>.made;
}

method Literal ($/) {
  my $lit = $<NumericLiteral>.made || $<StringLiteral>.made;
  $/.make: -> $ctx { $lit };
}

method NumericLiteral ($/) {
  $/.make: +$/;
}

method StringLiteral ($m) {
  my $val = ~$m;
  my $quot = $m<q>; #>;
  $val ~~ s:g/ $quot**2/$quot/;
  $m.make: $val;
}

method ParenthesizedExpr ($/) {
  $/.make: $<Expr>.made;
}

method ContextItemExpr ($/) { ... };

method FunctionCall ($/) { ... };

method SingleType ($/) { ... }

method SequenceType ($/) { ... };

method OccurrenceIndicator ($/) { ... };

method ItemType ($/) { ... };

method AtomicType ($/) { ... };

method KindTest ($/) { ... };

method AnyKindTest ($/) { ... };

method DocumentTest ($/) { ... };

method TextTest ($/) { ... };

method CommentTest ($/) { ... };

method PITest ($/) { ... };

method AttributeTest ($/) { ... };

method AttribNameOrWildcard ($/) { ... };

method SchemaAttributeTest ($/) { ... };

method AttributeDeclaration ($/) { ... };

method ElementTest ($/) { ... };

method ElementNameOrWildcard ($/) { ... };

method SchemaElementTest ($/) { ... };

method ElementDeclaration ($/) { ... };

method AttributeName ($/) { ... };

method ElementName ($/) { ... };

method TypeName ($/) { ... };

method QName ($/) {
  my %qname = :Prefix($<Prefix>.made), :LocalPart($<LocalPart>.made);
  $/.make: { %qname }
};

method NCName ($/) {
  $/.make: ~$/
};

#SKIPPED: NameStartChar NameChar

my sub matchany ($ctx) {
  $ctx;
}

multi sub testAxis('child', Code $nodetest, $ctx) {
  $ctx.nodes.grep: -> $node { $nodetest($node); };
}

multi sub testAxis('descendant', Code $nodetest, $ctx) {
  my @nodes = $ctx.nodes;
  my @dnodes;

  for @nodes.grep: -> $n { $n.can('nodes') && $n.nodes } -> $node {
    $nodetest($node) and @dnodes.push: $node;
    @dnodes.push: testAxis('descendant', $nodetest, $node);
  }

  @dnodes;
}

multi sub testAxis('parent', Code $nodetest, $ctx) {
  set(@($ctx).map: -> $n { $n.can('parent') ?? $nodetest($n.parent) !! () }).keys;
}

multi sub testAxis('attribute', Code $nodetest, $ctx) {
  @($ctx).map: -> $n { $n.can('attribs') && $nodetest($n.attribs) or () };
}

multi sub testAxis(Str $unsupported, Code $nodetest, $ctx) {
  fail "{$unsupported} axis is unsupported";
}

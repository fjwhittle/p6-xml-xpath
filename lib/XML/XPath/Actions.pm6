use v6;
use XML;

unit class XML::XPath::Actions;

method Expr ($/) {
  $/.make: -> $ctx {
    $<ExprSingle>».made».($ctx).map(*.flat).flat.list;
  }
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
      for @($<AndExpr>) {
	last if $r = .made.($ctx).grep(?*).list;
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
      for @($<ComparisonExpr>) {
	last unless $r = .made.($ctx).grep(?*).list;
      }
      $r;
    }
  } else {
    $/.make: $<ComparisonExpr>[0].made;
  }
}

method ComparisonExpr ($/) {
  if $<RangeExpr>.end {
    my $m = $/;
    $/.make: sub ($ctx --> Bool) {
      my @cval = $m<RangeExpr>[0,1]».made».($ctx)».grep(*.defined)».list;
      my Code $opc;
      if my $op = ~$m<ValueComp> {
	given $op.lc {
	  $opc = &infix:<eq> when 'eq';
	  $opc = &infix:<ne> when 'ne';
	  $opc = &infix:<lt> when 'lt';
	  $opc = &infix:<le> when 'le';
	  $opc = &infix:<gt> when 'gt';
	  $opc = &infix:<ge> when 'ge';
	}
	return $opc(|@cval);
      } elsif $op = ~$m<GeneralComp> {
	# XPath's non-equality rule for lists differs from Perl's junctions:
	# Use the difference of sets.
	return ?[⊖](|@cval) if $op eq '!=';
	given $op {
	  $opc = &infix:<eq> when '=';
	  $opc = &infix:<lt> when '<';
	  $opc = &infix:<le> when '<=';
	  $opc = &infix:<gt> when '>';
	  $opc = &infix:<ge> when '>=';
	}
	return ?$opc(|@cval».any);
      }
      return $m<NodeComp>.made.($ctx) if $m<NodeComp>;
    }
  } else {
    $/.make: $<RangeExpr>[0].made;
  }
}

method RangeExpr ($/) {
  if $<AdditiveExpr>.end {
    $/.make: -> $ctx { $<AdditiveExpr>[0].made.($ctx)[0]..$<AdditiveExpr>[1].made.($ctx)[0]; };
  } else {
    $/.make: $<AdditiveExpr>[0].made;
  }
}

method AdditiveExpr ($/) {
  if $<MultiplicativeExpr>.end {
    $/.make: -> $ctx {
      my $value = $<MultiplicativeExpr>.shift.made.($ctx)[0];
      for @($<MultiplicativeExpr>».made».($ctx)»[0]) Z @($<op>) -> [$next, $op] {
	if ($value | $next).does(Str) {
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
    $/.make: -> $ctx {
      my $value = $<UnionExpr>.shift.made.($ctx)[0];

      for @($<UnionExpr>».made».($ctx)»[0]) Z @($<op>) -> [$next, $op] {
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

multi sub get-source-order($n where *.parent.can('index-of') ) {
  %so-cache{$n} //= (get-source-order($n.parent), $n.parent.index-of($n)).flat;
}

multi sub get-source-order($n) {
  ();
};

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
    $/.make: -> $ctx {
      my @submatch = $<InstanceofExpr>.map: { .<TreatExpr><CastableExpr><CastExpr><UnaryExpr>.made };
      my @opl = $<op>».Str;
      my $value = @submatch.shift.($ctx);
      $value.all ~~ XML::Node or X::TypeCheck.new('IntersectExceptExpr only works on XML::Node objects').die;
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
      $value .= keys;
      temp %so-cache;
      $value .= sort({ get-source-order($^a) cmp get-source-order($^b) });
      $value .= list;
      $value;
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
    $/.make: -> $ctx is copy {
      for (@($<sep>) Z @($<StepExpr>)) -> [$sep, $expr] {
        if $expr<AxisStep> {
          $ctx = $expr.made.($ctx, $sep);
        } else {
          $ctx = $expr.made.($ctx);
        }
      }

      $ctx.list;
    }
  }
}

method StepExpr ($/) {
  $/.make: ($<FilterExpr> || $<AxisStep>).made;
}

method AxisStep($m) {
  my ($axis, $nodetest);
  if $m<AbbrevForwardStep> {
    $m.make: sub ($ctx, $sep) {
      $axis = $m<AbbrevForwardStep><attr> eq '@' ?? 'attribute' !! ($sep eq '//') ?? 'descendant' !! 'child';
      $nodetest = $m<AbbrevForwardStep><NodeTest>.made;
      testAxis($axis, $nodetest, $ctx);
    }
  } elsif $m<AbbrevReverseStep> {
    $m.make: sub ($ctx, $sep) {
      $axis = 'parent';
      $nodetest = &matchany;
      testAxis($axis, $nodetest, $ctx);
    }
  } else {
    $m.make: sub ($ctx, $sep) {
      $axis = ~$m<Axis>;
      $nodetest = $m<NodeTest>.made;
      testAxis($axis, $nodetest, $ctx);
    }
  }

  if $m<Predicate> {
    $m.made.wrap: -> $ctx , $sep {
      my @context = callsame;
      for $m<Predicate>»<Expr> -> $pred {
	@context .= grep: {
	  $pred.made.($_).all;
	};
	@context .= list;
      }
      @context;
    }
  }
}

# SKIPPED: Axis AbbrevForwardStep AbbrevReverseStep

method NodeTest ($/) {
  $/.make: ($<NameTest> || $<KindTest>).made;
}

method NameTest ($/) {
  my ($wildcard, $prefix, $lname) = ~($<Wildcard> // ''), ~($<QName><Prefix> // ''), ~($<QName><LocalPart> // '');
  if $wildcard && $wildcard eq '*' {
    $/.make: -> $ctx { $ctx }
  } elsif $prefix {
    $/.make: -> $ctx { ... }
  } else {
    $/.make: -> $ctx {
      quietly {
	if $ctx.?name eq $lname {
	  $ctx;
	} elsif $ctx ~~ Hash {
	  $ctx.{$lname} || Nil;
	} else {
	  Nil;
	}
      }
    }
  }
}

# SKIPPED: Wildcard

method FilterExpr ($/) {
  if $<Predicate> {
    $/.make: -> $ctx is copy {
      $ctx = $<PrimaryExpr>.made.($ctx);
      $<Predicate><Expr>.made.($ctx) and $ctx;
    };
  } else {
    $/.make: $<PrimaryExpr>.made;
  }
}

# SKIPPED: Predicate

method PrimaryExpr ($/) {
  $/.make: ($<Literal> || $<VarName> || $<ParenthesizedExpr> || $<ContextItemExpr> || $<FunctionCall>).made;
}

method Literal ($/) {
  my $lit = ($<NumericLiteral> || $<StringLiteral>).made;
  $/.make: -> $ctx { $lit };
}

method NumericLiteral ($/) {
  $/.make: +$/;
}

method StringLiteral ($m) {
  my $val = ~$m;
  my $quot = $m<q>;
  $val ~~ s:g/$quot**2/$quot/;
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

method KindTest($/) {
  $/.make: -> $ctx { ... };
}

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
  $ctx.nodes.grep(-> $node { $nodetest($node); }).list;
}

multi sub testAxis('descendant', Code $nodetest, $ctx) {
  my @nodes = $ctx.?nodes or return;
  my @dnodes;

  for @nodes.grep: { .?nodes } -> $node {
    $nodetest($node) and @dnodes.push: $node;
    @dnodes.append: testAxis('descendant', $nodetest, $node);
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
  fail "{$unsupported} axis is unsupported for {$ctx.^name}";
}

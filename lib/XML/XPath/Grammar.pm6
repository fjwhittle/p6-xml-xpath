use v6;

unit grammar XML::XPath::Grammar;

rule TOP { <Expr> }

regex ws { [ <!ww> \s || <.comment> ]* }

regex comment { '(:' [ <.comment> || . ]*? ':)' }

rule Expr { <ExprSingle>+ % ','
	      # This doesn't work:
	      #{ $/.to == $/.orig.chars or $/.postmatch.substr(0, 1) eq ')' or die "XPath expression error at #{$/.to} before '{$/.postmatch}'" }
	}

rule ExprSingle { <ForExpr> || <QuantifiedExpr> || <IfExpr> || <OrExpr> }

rule ForExpr { <SimpleForClause> 'return' <ExprSingle> }

rule SimpleForClause { 'for' ( '\$' <VarName> 'in' <ExprSingle> )+ % [ ',' ] }

rule QuantifiedExpr { $<op> = [ || < some every > ] <SimpleForClause> 'satisfies' <satisfies=ExprSingle> }

rule IfExpr { 'if' '(' <if=Expr> ')' 'then' <then=ExprSingle> ['else' <else=ExprSingle>]? }

rule OrExpr { <AndExpr>+ % 'or' }

rule AndExpr { <ComparisonExpr>+ % 'and' }

rule ComparisonExpr { <RangeExpr>** 1..2 % [ <ValueComp> || <GeneralComp> || <NodeComp> ] }

rule RangeExpr { <AdditiveExpr>** 1..2 % [ 'to' ]  }

rule AdditiveExpr { <MultiplicativeExpr> + % $<op> = <[ + - ]> }

rule MultiplicativeExpr { <UnionExpr> + % $<op> =  [|| < * div idiv mod >] }

rule UnionExpr { <IntersectExceptExpr> + % $<op> = [|| < union | >]  }

rule IntersectExceptExpr { <InstanceofExpr> + % $<op> = [|| < intersect except >] }

rule InstanceofExpr { <TreatExpr> [ 'instance' 'of' <SequenceType> ]? }

rule TreatExpr { <CastableExpr> [ 'treat' 'as' <SequenceType> ]? }

rule CastableExpr { <CastExpr> [ 'castable' 'as' <SingleType> ]? }

rule CastExpr { <UnaryExpr> [ 'cast' 'as' <SingleType> ]? }

rule UnaryExpr { [$<op> = <[+-]> ]* <ValueExpr=.PathExpr> }

token GeneralComp { '=' || '!='  || '<=' || '<' || '>=' || '>'  }

token ValueComp { || < eq ne lt le gt ge > }

token NodeComp { 'is' || '<<' || '>>' }

# xgs: leading-lone-slash
# Shortcutting RelativePathExpr
rule PathExpr { $<sep> = ['/'**0..2] <StepExpr>+ % $<sep> = ['/'**1..2] || $<root> = '/' }

regex StepExpr { <FilterExpr> || <AxisStep> }

rule AxisStep { [ <Axis> '::' <NodeTest> || <AbbrevForwardStep> || <AbbrevReverseStep> ] <Predicate>* }

token Axis {  || < child descendant attribute self descendant-or-self following-sibling
		following namespace  parent ancestor preceding-sibling preceding ancestor-or-self > }

rule AbbrevForwardStep { $<attr> = '@'? <NodeTest> }

token AbbrevReverseStep { '..' }

rule NodeTest { <KindTest> || <NameTest> }

rule NameTest { <QName> || <Wildcard> }

rule Wildcard { '*' || (<Prefix=.NCName>':*') || ('*:'<LocalPart=.NCName>) }

rule FilterExpr { <PrimaryExpr> <Predicate>* }

rule Predicate { '[' <Expr> ']'}

rule PrimaryExpr { <Literal> || '$' <VarName=.QName> || <ParenthesizedExpr> ||
		     <ContextItemExpr> || <FunctionCall> }

token Literal { <NumericLiteral> || <StringLiteral> }

token NumericLiteral { [ [\d*\.]? \d+ ][ <[e E]> <[+ -]>? \d+ ]? }

token StringLiteral { $<q>="'" <( [\'**2 || <-[']>]* )> "'" ||
                      $<q>='"' <( [\"**2 || <-["]>]* )> '"' }

rule ParenthesizedExpr { '(' <Expr>? ')' }

token ContextItemExpr { '.' <!before '.'> }

rule FunctionCall { <QName> '(' (<ExprSingle> (',' <ExprSingle>)* )? ')' # xgs: reserved-function-names
		      # gn: parens
		}

rule SingleType { <AtomicType> '?'? }

rule SequenceType { ('empty-sequence' '(' ')')
		      || (<ItemType> <OccurrenceIndicator>?) }

token OccurrenceIndicator { <[? * +]> }; # xgs: occurrence-indicators

rule ItemType { <KindTest> || ('item' '(' ')') || <AtomicType> }

token AtomicType { <QName> }

rule KindTest { <DocumentTest> || <ElementTest> || <AttributeTest> || <SchemaElementTest> ||
		  <SchemaAttributeTest> || <PITest> || <CommentTest> || <TextTest> || <AnyKindTest> }

rule AnyKindTest { 'node' '(' ')' }

rule DocumentTest { 'document-node' '(' ( <ElementTest> || <SchemaElementTest>)? ')' }

rule TextTest { 'text' '(' ')' }

rule CommentTest { 'comment' '(' ')' }

rule PITest { 'processing-instruction' '(' (<NCName> || <StringLiteral>)? ')' }

rule AttributeTest { 'attribute' '(' (<AttribNameOrWildcard> (',' <TypeName>)? )? ')' }

rule AttribNameOrWildcard { <AttributeName> || '*' }

rule SchemaAttributeTest { 'schema-attribute' '(' <AttributeDeclaration> ')' }

rule AttributeDeclaration { <AttributeName> }

rule ElementTest { 'element' '(' ( <ElementNameOrWildcard> (',' <TypeName> '?'? )? )? ')' }

rule ElementNameOrWildcard { <ElementName> || '*'}

rule SchemaElementTest { 'schema-element' '(' <ElementDeclaration> ')' }

rule ElementDeclaration { <ElementName> }

token AttributeName { <QName> }

token ElementName { <QName> }

token TypeName { <QName> }

#`(@todo:)

token QName { [<Prefix=.NCName>':']?<LocalPart=.NCName> }

token NCName { <.NameStartChar><.NameChar>* }

token NameStartChar { <[ \w _ ]> }

token NameChar { <[ \w \d \. _ - ]> }

package Foswiki::Plugins::SqlGridPlugin::SqlParser;

use strict;
use warnings;
use HOP::Lexer 'string_lexer';

#use constant DEBUG => 1; # toggle me

=begin TML

---+++ parse($sql)

Parses an SQL expression and returns a hashtable that contains:
   * fromwhere_connectorparam - the part of the SQL query after 'from'.  
   * columns - a comma-separated list of columns.
   * col_${col}_expr_connectorparam - for each column, the sql expression for that column.

Adapted from http://www.perl.com/pub/2006/01/05/parsing.html
=cut

sub parse {
    my $sql = $_[0];
#print "PARSING: $sql\n"
#if DEBUG;
    my @columns;
    my %colExprs;

	my $lexer = string_lexer(
		$sql,
		[ 'KEYWORD', qr/\s*\b(?i:select|from|as)\b/   ],
		[ 'COMMA',   qr/\s*,/                         ],
		[ 'OP',      qr{[-=+*/]}                      ],
		[ 'LPAREN',   qr/\(/                          ],
		[ 'RPAREN',   qr/\)/                          ],
		[ 'TEXT',    qr/(?:\w+|'\w+'|"\w+")/          ],
		[ 'SPACE',   qr/\s*/                          ],
	);
	
	my $columnExpr = '';
	my %columnExpr;
	my $inside_parens = 0;
	while ( defined ( my $token = $lexer->() ) ) {
		my ( $label, $value );
		if (ref($token) eq 'ARRAY' ) {
			( $label, $value ) = @$token;
		} else {
			( $label, $value ) = ('', $token);
		}
		
#print "  [$label  $value]\n"
#if DEBUG;
		$inside_parens += 1 if 'LPAREN' eq $label;
		$inside_parens -= 1 if 'RPAREN' eq $label;

		my $next;
		if ($inside_parens == 0 && $label eq 'TEXT' && defined ( $next = $lexer->('peek') ) && ref($next) eq 'ARRAY' ) {
			my ( $next_label, $next_value ) = @$next;
			if ( 'COMMA' eq $next_label ) {
				$value = removeQuote($value);
				push @columns, $value;
				$columnExpr{$value} = $columnExpr;
				$columnExpr = '';
				$lexer->();
				next;
			}
			elsif ( 'KEYWORD' eq $next_label && $next_value =~ /from$/i) {
				$value = removeQuote($value);
				push @columns, $value;
				$columnExpr{$value} = $columnExpr;
				$columnExpr = '';
				last; # we're done
			}
		}

		if ('KEYWORD' ne $label) {
			$columnExpr .= $value;
		}
	}

	my $fromwhere = '';
	while ( defined ( my $token = $lexer->() ) ) {
		if (ref($token) eq 'ARRAY') {
			my ( $label, $value ) = @$token;
			$fromwhere .= $value;
		} else {
			$fromwhere .= $token;
		}
	}
	$fromwhere =~ s/^\s+//;
	$fromwhere =~ s/\s+$//;
	$fromwhere =~ /\swhere\s/i
		or $fromwhere .= " where 1=1";

    my %ret;
	$ret{fromwhere_connectorparam} = $fromwhere;
    $ret{columns} = join ',', @columns;
    for my $col (@columns) {
    	if ($columnExpr{$col} =~ /\S/) {
    		my $tmp = $columnExpr{$col};
    		$tmp =~ s/^\s+//;
    		$tmp =~ s/\s+$//;
    		$ret{"col_${col}_expr_connectorparam"} = $tmp;
    	} else {
	    	$ret{"col_${col}_expr_connectorparam"} = $col;
    	}
    }

    return \%ret;
}


sub removeQuote {
    my $value = $_[0];
    $value =~ s/^["']//;
    $value =~ s/["']$//;
    return $value;
}

1;

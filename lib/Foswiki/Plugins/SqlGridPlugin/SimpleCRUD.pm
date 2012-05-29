package Foswiki::Plugins::SqlGridPlugin::SimpleCRUD;

use strict;
use warnings;

use constant SUCCESS_JSON => '{ "actionStatus": 200 }';

use constant DEBUG => 1; # toggle me
sub writeDebug($) {
#	my $f = __FILE__;
#	$f =~ s@^.*[/\\]([^/\\]+[/\\][^/\\]+)$@$1@; #Dir/File.pm
	
	my ($package, $filename, $line, $subroutine, $hasargs,
    $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash)
     = caller(1);
	
	$subroutine =~ s@^.*::([^:]+::[^:]+)$@$1@;
	
	Foswiki::Func::writeDebug($subroutine, $_[0]);
}

sub _getRestParams {
	my $request = $_[0];

	my $dbconn = $request->param('dbconn');
	my $table = $request->param('table');
	my $idcol = $request->param('idcol');

	$dbconn =~ s/[^\w]//g;
	$table =~ s/[^\w]//g;
	$idcol =~ s/[^\w]//g;

	my @keys = ();
	my @args = ();
	for my $p ($request->param()) {
		my $col = $p;
		if ($col =~ s/^col_// && $col ne $idcol) {
			$col =~ s/[^\w]//g;
			my $val = $request->param($p);
			push @keys, $col;
			push @args, $val;
		}
	}
	my $idval = $request->param("col_$idcol");

	return ($dbconn, $table, $idcol, $idval, \@keys, \@args);
}

sub restSimpleupdate {
	my ($session, $subject, $verb, $response) = @_;
	my $request = Foswiki::Func::getCgiQuery();
	writeDebug($request->query_string())
		if DEBUG;

	my ($dbconn, $table, $idcol, $idval, $keys, $args) = _getRestParams($request);
	my $setStmt = join ', ', map { "$_ = ?" } @$keys;
	
	my $sql = "UPDATE $table SET $setStmt WHERE $idcol = ?";
	push @$args, $idval;

writeDebug($sql . join ',', @$args);

	my $sth = Foswiki::Plugins::SqlPlugin::execute($dbconn, $sql, @$args);
	$sth->finish;

	return SUCCESS_JSON;
}

sub restSimpleinsert {
	my ($session, $subject, $verb, $response) = @_;
	my $request = Foswiki::Func::getCgiQuery();
	writeDebug($request->query_string())
		if DEBUG;

	my ($dbconn, $table, $idcol, $idval, $keys, $args) = _getRestParams($request);


	my $names = join ', ', @$keys;
	my $questions = join ', ', map { '?' } @$keys;

	my $sql = "INSERT INTO $table( $names ) VALUES ($questions)";

writeDebug($sql . join ',', @$args);
	my $sth = Foswiki::Plugins::SqlPlugin::execute($dbconn, $sql, @$args);
	$sth->finish;

	return SUCCESS_JSON;
}

sub restSimpledelete {
	my ($session, $subject, $verb, $response) = @_;
	my $request = Foswiki::Func::getCgiQuery();
	writeDebug($request->query_string())
		if DEBUG;

	my ($dbconn, $table, $idcol, $idval, $keys, $args) = _getRestParams($request);

	my $sql = "DELETE FROM $table WHERE $idcol = ?";
	my @args = ($idval);

writeDebug($sql . join ',', @args);
	my $sth = Foswiki::Plugins::SqlPlugin::execute($dbconn, $sql, @args);
	$sth->finish;

	return SUCCESS_JSON;
}

1;

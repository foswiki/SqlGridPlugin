package Foswiki::Plugins::SqlGridPlugin::SqlMysqlConnector;

use strict;
use warnings;

use Foswiki::Plugins::SqlGridPlugin::SqlConnector ();
use Foswiki::Plugins::SqlPlugin;

use POSIX qw( ceil );

our @ISA = qw( Foswiki::Plugins::SqlGridPlugin::SqlConnector );

use constant DEBUG => 1; # toggle me
sub writeDebug($) {
	my $f = __FILE__;
	$f =~ s@^.*[/\\]([^/\\]+[/\\][^/\\]+)$@$1@; #Dir/File.pm
	Foswiki::Func::writeDebug($f, $_[0]);
}

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  return $this;
}

=begin TML

---++ ClassMethod restHandleSearch( $request, $response )

search backend 

MySQL?
http://www.arraystudio.com/as-workshop/mysql-get-total-number-of-rows-when-using-limit.html

Oracle
https://forums.oracle.com/forums/thread.jspa?threadID=415724
SELECT last_name FROM 
   (SELECT last_name, ROW_NUMBER() OVER (ORDER BY last_name) R FROM employees)
   WHERE R BETWEEN 51 and 100;

Sybase
http://www.sitepoint.com/forums/showthread.php?58770-Limit-records-displayed-in-Sybase-SQL
http://forums.whirlpool.net.au/archive/1226436

=cut


#perl -d -T  -MDBI  ./rest /JQGridPlugin/gridconnector connector=mysql connector_dbiconn=gothams
#b postpone Foswiki::Plugins::JQGridPlugin::DBDMysqlConnector::restHandleSearch
sub restHandleSearch {
  my ($this, $request, $response) = @_;
  my $isSearch = ($request->param('_search') || '') eq "true";
  my $theDbconn = $request->param('dbconn_connectorparam');

	writeDebug($request->queryString())
		if DEBUG;

print STDERR $request->queryString()
		if DEBUG;

  # TML-defined parameters
  my @columns = split ',', $request->param('columns');
  my %columns = map { $columns[$_] => $_ } 0 .. $#columns;
  my $fromWhere = $request->param('fromwhere_connectorparam');
  my $fromWhereParams = $request->param('fromwhere_params_connectorparam') || '';
  my @fromWhereParams = split /\s*,\s*/, $fromWhereParams;
  my $idcol = $request->param('idcol_connectorparam');
  my $idcolPos = $columns{$idcol};

  # user-defined parameters
  my $sidx = $request->param('sidx') || $columns[0];
#  my $sort = exists $columns{$request->param('sidx')} ? $columns{$request->param('sidx')} : 1;
  my $sord = $request->param('sord') || 'asc';
  my $rowsPerPage = $request->param('rows') || 10;
  my $curPage = $request->param('page') || 1;

  my %exprs = ();
  for my $col (@columns) {
    $exprs{$col} = $request->param("col_${col}_expr_connectorparam") || $col;
  }
  my $selectList = join ',', map { "$exprs{$_} as $_" } @columns;

  my $sort = exists $exprs{$sidx} ? $exprs{$sidx} : $exprs{$columns[0]};

  my $searchWhere = '';
  if ($isSearch) {
    for my $col (@columns) {
      if ($request->param($col)) {
        $searchWhere .= " AND $exprs{$col} like '\%" . $request->param($col) . "\%'";
      }
    }
  }
  my $selectQuery = "select $selectList $fromWhere $searchWhere";
  my $countQuery = "select count(*) $fromWhere $searchWhere";

# XX TODO add search params
  my @params = @fromWhereParams;
#####

  my $sth = Foswiki::Plugins::SqlPlugin::execute($theDbconn, $countQuery, @params);
  my $count;
  ($count) = $sth->fetchrow_array;
  $sth->finish;

  my $totalPages = 0;
  if ($count > 0) {
    $totalPages = ceil(($count + 0.0) / $rowsPerPage);
  }
  if ($curPage > $totalPages) {
    $curPage = $totalPages;
  }

  my $start = ($curPage == 0) ? 0 : $rowsPerPage * $curPage - $rowsPerPage;

  my $selectWhereQuery = "$selectQuery ORDER BY $sort $sord LIMIT $start, $rowsPerPage";
Foswiki::Func::writeDebug("DBDMysqlConnector.pm", $selectWhereQuery);

  my $body = "";
  $sth = Foswiki::Plugins::SqlPlugin::execute($theDbconn, $selectWhereQuery, @params);
  while (my @row = $sth->fetchrow_array()) {
    $body .= "<row id='$row[$idcolPos]'>";
    for my $data (@row) {
      if (!defined($data)) {
        $body .= "<cell></cell>";
        next;
      }
      #SMELL should let the user configure if the column is a number or a string.
      if ($data =~ /^[\-\.\d]+$/) {
        $body .= "<cell>$data</cell>";
      } else {
        $body .= "<cell><![CDATA[$data]]></cell>";
      }
    }
#    $body .= "<cell><![CDATA[$row[0]]]></cell> <cell>$row[1]</cell>";
#    $body .= join ' ', map { "<cell>$_</cell>" } @row;
    $body .= "</row>";
  }
  $sth->finish;

  my $header = <<"HERE"
<rows>
<page>$curPage</page>
<total>$totalPages</total>
<records>$count</records>
HERE
;
my $footer = <<"HERE"
</rows>
HERE
;
#  my $result = "got $count rows";
#Foswiki::Func::writeDebug("mysql", $header.$body.$footer);
  $this->{session}->writeCompletePage($header.$body.$footer, 'view', 'text/xml');
}




1;


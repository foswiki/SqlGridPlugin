# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2012 Kip Lubliner, http://kiplubliner.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package Foswiki::Plugins::SqlGridPlugin


=cut

package Foswiki::Plugins::SqlGridPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Foswiki::Plugins::JQueryPlugin::Plugins;
use Foswiki::Plugins::SqlPlugin;

use Foswiki::Plugins::SqlGridPlugin::SqlParser;

our $VERSION = '$Rev: 13288 $';
our $RELEASE = '0.0.1';
our $SHORTDESCRIPTION = 'Javascript interface for updating an SQL database';
our $NO_PREFS_IN_TOPIC = 1;

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

# SMELL make this a preference
my $purgeSqlDependencies = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }
    Foswiki::Func::registerTagHandler( 'SQLGRID', \&SQLGRID );
    Foswiki::Func::registerRESTHandler( 'simpleupdate', \&restSimpleupdate );
    Foswiki::Func::registerRESTHandler( 'simpleinsert', \&restSimpleinsert );
    return 1;
}

# I experimented with caching, however it made no performance difference to my queries.
# Leaving this code in here for now just in case.
#
#use File::Spec;
#use Storable;
#
#sub loadSql0 {
#	my $sql = $_[0];
#	my $workArea = Foswiki::Func::getWorkArea( 'SqlGridPlugin' );
#	my $fileCache = File::Spec->catfile($workArea, 'queryCache.txt');
#
#	my $cache = {};
#	if (-f $fileCache) {
#		$cache = retrieve($fileCache);
#	}
#	if (exists $cache->{$sql}) {
#		return $cache->{$sql};
#	}
#	$cache->{$sql} = Foswiki::Plugins::SqlGridPlugin::SqlParser::parse($sql);
#	store $cache, $fileCache;
#	return $cache->{$sql};
#}

sub loadSql {
	my $sql = $_[0];
	return Foswiki::Plugins::SqlGridPlugin::SqlParser::parse($sql);
}

sub SQLGRID {
    my($session, $params, $topic, $web, $topicObject) = @_;
	writeDebug("attrs " . $params->stringify())
		if DEBUG;

	if (exists $params->{templates}) {
	    my $attrs = _mergeTemplates('templates', $web, $params->stringify());
	    $params = Foswiki::Attrs->new($attrs);
	}

	unless (defined $params->{'fromwhere_connectorparam'} or defined $params->{'sql'}) {
	    writeDebug("Rendering as empty string because neither attribute 'fromwhere_connectorparam', 'sql' was present")
            if DEBUG;
	    return "";
	}

	my $id;
	if (exists $params->{id}) {
		$id = $params->{id};
	} else {
		$id = $params->{id} = "SqlGridPlugin" . Foswiki::Plugins::JQueryPlugin::Plugins::getRandom();
	}
	my $jsFunc = "onSqlGridLoad$id";
	if (exists $params->{gridComplete}) {
		$params->{gridComplete} = "function() {  " . $jsFunc . "(); " . $params->{gridComplete} . " }";
	} else {
		$params->{gridComplete} = $jsFunc;
	}
	
	my $idcol = $params->{idcol_connectorparam} = $params->remove('idcol') || '';

	$params->{fromwhere_params_connectorparam} = $params->remove('sqlparams') || '';

	my $theSqlQuery = $params->{sql} || '';
	if ($theSqlQuery) {
        my $h = loadSql($theSqlQuery);
	    while( my ($k,$v) = each %$h) {
		    $params->{$k} = $v;
    	}
	}

	my $table = $params->remove('table');
	my $dbconn = $params->{'dbconn_connectorparam'};

	my $editform = $params->{'editform'} || '';
	my $addform = $params->{'addform'} || '';

#   SMELL Think that this is dead code.
	my $onSelectRowScript = '';
#	if ($onSelectRow) {
	if (0) {
		$onSelectRowScript = <<EOQ;
    jQuery('#$id').jqGrid('setGridParam', {
	    onSelectRow: function() { alert('select row') }
    });
    //.trigger('reloadGrid');
EOQ
	}

    my $buttonScripts = '';
    if (exists $params->{sqlgridbuttons}) {
        my %formactionargs;
        my %sqlgridbuttons;
        while (my ($k,$v) = each %{$params}) {
            if ($k =~ /(.*)_formactionarg$/) {
                $formactionargs{$1} = $v;
            }
            if ($k =~ /^(.*)_(.*)_sqlgridbutton$/) {
                $sqlgridbuttons{$1}->{$2} = $v;
            }
        }
        my $formactionargs = join ';', map { "$_=$formactionargs{$_}" } keys %formactionargs;

        my @buttons = split ',', $params->{sqlgridbuttons};
        for my $button (@buttons) {
            $button =~ s/\s+//g;
            $buttonScripts .= _addGridButton($id, $button, $sqlgridbuttons{$button}, $formactionargs, $params);
        }
    }

	my $script=<<EOQ
%JQREQUIRE{"ui::dialog, ui::button"}%
%ADDTOZONE{"script" id="SqlGridPlugin" requires="JQUERYPLUGIN::UI::DIALOG"
text="<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/SqlGridPlugin/gridfuncs.js'></script>
<script type='text/javascript'>
  var sqlPluginObjs = {}; // SMELL - should be run once
  sqlPluginObjs.$id = {};
  sqlPluginObjs.$id.hasInitRun = 0;

//  var hasRan_$jsFunc = 0;
  function $jsFunc() {
    if (sqlPluginObjs.$id.hasInitRun != 0)
      return;
    sqlPluginObjs.$id.hasInitRun = 1;
    var pagerId = jQuery('#$id').jqGrid('getGridParam', 'pager');

    $buttonScripts

$onSelectRowScript

  }
</script>"}%
EOQ
;
    return "$script\n\%GRID{" . $params->stringify() . "}\%";
}

sub _addGridButton ($$$$$) {
    my ($id, $button, $buttonParams, $formactionargs, $params) = @_;

	my %funcArgs = ( gridId => "'$id'" );
	if (exists $buttonParams->{needrow}) {
	    $funcArgs{requireSelection} = $buttonParams->{needrow};
	}
	if ($buttonParams->{form}) {
    	$funcArgs{form} = "'" . $buttonParams->{form} . "'";
	} else {
    	$funcArgs{form} = "'" . Foswiki::Func::getScriptUrl(
                 'System', 'SqlGridPluginErrorMessages', 'view',
                 skin => 'text',
                 errortype => 'noform',
                 button => $button
                 ) . "'";
	}

    my $formAction = $buttonParams->{formaction} ||
            Foswiki::Func::getScriptUrl(
                 'System', 'SqlGridPluginErrorMessages', 'view',
                 skin => 'text',
                 errortype => 'noformaction',
                 button => $button
                 );
    if ($formactionargs) {
        if ($formAction =~ /\?/) {
             $formAction .= ";$formactionargs";
        } else {
            $formAction .= "?$formactionargs";
        }
    }
    $funcArgs{formAction} = "'$formAction'";

	my $funcArgs = join ', ', map { "$_: $funcArgs{$_}" } keys %funcArgs;
	my $caption = $buttonParams->{caption} || $button;
	my $hover = $buttonParams->{hover} || $button;
	my $iconCode = defined $buttonParams->{icon}
	    ? "      buttonicon:'$buttonParams->{icon}',"
	    : "";

	return <<EOQ;
    jQuery('#$id').jqGrid('navButtonAdd', pagerId, {
      caption:'$caption',
      title:'$hover', 
      $iconCode
      onClickButton: function () {
        sqlgrid_showForm({ $funcArgs });
      }
    });
EOQ
}


# Gets attributes from each topic in $templates, and creates a big string that contains all of them.
# Attributes defined in templates can be overridden - relies on parsing behavior of Foswiki::Attrs class,
# that if an attribute is defined more than once then the last value wins.

sub _mergeTemplates($$$);

sub _mergeTemplates($$$) {
    my ($templatesAttr, $origWeb, $params) = @_;
    my $newParams = '';

    $params =~ s/\b$templatesAttr\s*=\s*"(.*?)"/ /
        or return $params;
    for my $template (split ',', $1) {
        $template =~ s/\s+//g;
        my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($origWeb, $template);
        writeDebug("merging $web.$topic")
            if DEBUG;
        my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
        my $attrs;
        if (defined $text and ($attrs) = $text =~ /\%SQLGRID{(.*?)}\%/s) {
            if ($attrs =~ /\%\w+{/) {
                # Need to evaluate macros
                $text =~ s/.*\%SQLGRID{/SQLGRID_xyzzy_pancakes{/s;
                $text = Foswiki::Func::expandCommonVariables($text, $topic, $web, $meta);
                ($attrs) = $text =~ /SQLGRID_xyzzy_pancakes{(.*?)}\%/s
            }
            $newParams .= ' ' . _mergeTemplates($templatesAttr, $web, $attrs);
        }
    }
    $newParams .= ' ' . $params;

    writeDebug("Returning $newParams")
       if DEBUG;
    return $newParams;
}

# REST

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

#	cleanPageCache($table);

	return "1";
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

#	cleanPageCache($table);

	return "1";
}

#sub cleanPageCache {
#	my $table = $_[0];

	
#}

1;

__END__

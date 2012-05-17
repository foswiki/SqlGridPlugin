package Foswiki::Plugins::SqlGridPlugin::SqlConnector;

use strict;
use warnings;

# SMELL
# should properly copy the class / fix up DbiContrib so that it can handle multiple DB defs.
use Foswiki::Plugins::SqlPlugin::Connection ();
use Foswiki::Plugins::JQGridPlugin::Connector ();
use Error qw(:try);
use Foswiki::AccessControlException ();
use Foswiki::Meta ();

our @ISA = qw( Foswiki::Plugins::JQGridPlugin::Connector );

use constant DEBUG => 1; # toggle me
sub writeDebug($) {
	my $f = __FILE__;
	$f =~ s@^.*[/\\]([^/\\]+[/\\][^/\\]+)$@$1@; #Dir/File.pm
	Foswiki::Func::writeDebug($f, $_[0]);
}


sub restHandleSave {
  my ($this, $request, $response) = @_;

writeDebug($request->queryString());


#  throw Error::Simple("NYI");
}


1;

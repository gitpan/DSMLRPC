#!/usr/bin/perl

use strict;
use HTTP::Daemon;
use HTTP::Status;
#use Data::Dumper;
use Shell;

use POSIX ":sys_wait_h";

use DSMLLDAP;

sub zombie_reaper { 
	while (waitpid(-1, WNOHANG) > 0) 
		{ } 
	$SIG{CHLD} = \&zombie_reaper; 
} 
$SIG{CHLD} = \&zombie_reaper;
my $child_pid = fork;
if ( $child_pid ) {
      	exit;
}


my $user = shift @ARGV || "cn=ipermgr,dc=iperbole,dc=bologna,dc=it";
my $pwd = shift @ARGV || "yaa94hIo";

my $host = shift @ARGV || '127.0.0.1';
my $port = shift @ARGV || 6890;


my $d = HTTP::Daemon->new(LocalAddr => $host,
		          LocalPort => $port,
			  Reuse => 1) || die;

POSIX::setuid(65534);
POSIX::setgid(65533);
print "Please contact me at: <URL:", $d->url, ">\n";
while (1) {
	while (my $client = $d->accept) {
	
		my $child_pid = fork;
		if ( $child_pid ) { 
			next; 
		} 
		elsif (defined ($child_pid)) { 
			HttpdChild($client); 
			exit; 	
		} 
		else { 
			print "HTTPD: fork failed: $!\n"; 
		}
		$client = undef;
	} 
	continue {
		$client->close; 
		undef ($client); 
	}
}

sub HttpdChild {
	my $httpd = shift;
	
	while (my $r = $httpd->get_request) {
		my $xml;
		my $xmlfile;
		my $local = time; chop $local;
		$xmlfile = "XML".$local;

		if ($r->method eq 'GET') {
			$httpd->send_error(RC_FORBIDDEN);
		}
		elsif ($r->method eq 'POST') {
			my $req = $r->content;
		#	open OUT, "> /tmp/req.xml";
		#	print OUT $req;
		#	close OUT;
			my $ldapObj = DSMLLDAP->new($user,$pwd);
			#$xml = $ldapObj->handle($req, $user, $pwd);
			$xml = $ldapObj->handle($req);
			
			open OUT, "> /tmp/$xmlfile";
			print OUT $xml;
			close OUT;
			$httpd->send_file_response("/tmp/$xmlfile");
			rm("/tmp/$xmlfile");

		}
		else {
			$httpd->send_error(RC_FORBIDDEN);
		}
	}

}


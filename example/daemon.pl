#!/usr/bin/perl

use strict;
use HTTP::Daemon;
use HTTP::Status;

use POSIX ":sys_wait_h";

use DSMLLDAP;

sub zombie_reaper { 
	while (waitpid(-1, WNOHANG) > 0) 
		{ } 
	$SIG{CHLD} = \&zombie_reaper; 
} 
$SIG{CHLD} = \&zombie_reaper;


my $host = $ARGV[0] || 'localhost';
my $port = $ARGV[1] || 3890;

my $d = HTTP::Daemon->new(LocalAddr => $host,
				          LocalPort => $port,
						  Reuse => 1) || die;

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
		
		}
		elsif ($r->method eq 'POST') {
			my $req = $r->content;
			open OUT, "> /tmp/req.xml";
			print OUT $req;
			close OUT;
			$xml = DSMLLDAP::handle($req);
			
			open OUT, "> $xmlfile";
			print OUT $xml;
			close OUT;
			$httpd->send_file_response($xmlfile);
			system("rm -f $xmlfile");

		}
		else {
			$httpd->send_error(RC_FORBIDDEN);
		}
	}

}


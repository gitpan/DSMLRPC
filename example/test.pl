#!/usr/bin/perl


use strict;
use ldap;

my $xml;
open IN, "< $ARGV[0]";
while (<IN>) {
	$xml .= $_;
}
close IN;
ldap::handle($xml);


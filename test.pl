#!/usr/bin/perl


use strict;
use DSMLLDAP;

my $xml;
open IN, "< $ARGV[0]";
while (<IN>) {
	$xml .= $_;
}
close IN;
DSMLLDAP::handle($xml);


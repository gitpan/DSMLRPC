require 5.004;
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'         => 'DSMLRPC',
	'VERSION_FROM' => 'DSMLRPC.pm',
	'PREREQ_PM'    => {
			'MIME::Base64' => 2,
			'XML::Parser'  => 2,
			'Net::LDAP'    => 0.3,
			'Data::Dumper'  => 1,
			'Crypt::PasswdMD5'  => 1.3
	},
	dist           => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
															  

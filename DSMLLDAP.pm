package DSMLLDAP; 

@ISA 	= qw(Exporter);
@EXPORT = qw(new doBind getSchema);

@EXPORT_OK = qw();


use strict;

use Net::LDAP;
use MIME::Base64;
use XML::Parser;
use Data::Dumper;

use DSMLRPC;

$VERSION = '0.1';

my $debug = 1;

my $xsd = "xsd/DSMLv2.xsd";

my $batchResponse_open =  '<?xml version="1.0" encoding="UTF-8"?><batchResponse xmlns="urn:oasis:names:tc:DSML:2:0:core">';

my $batchResponse_close = '</batchResponse>';


# Si connette ad un server LDAP
sub doBind {
	
	my $hostport = shift;
	my $user = shift || '';
	my $pwd = shift || '';
	
	
	my $ldap = Net::LDAP->new($hostport) or do
		{ 
			ErrorResponse("couldNotConnect", 
			   			  "LDAP has refused connection ($hostport)"); 
			print $@,"\n" if ($debug);
			return; 
		};
	my $msg;	
	$msg = $ldap->bind($user,
                       password=> $pwd,
                       version => 3)
		if ($user ne '');
	
	$msg = $ldap->bind(version => 3)
		if ($user eq '');
	
	if ($msg->is_error()) {
		print $msg->error_text if ($debug);
		ErrorResponse($msg->error_name, $msg->error_text);
		return;
	}
	else {
		return $ldap;
	}
}

# Ritorna lo schema usato dal server LDAP
sub getSchema {
	
	use Net::LDAP::Schema;
	
	my $hostport = shift;
	
	my $ldap = doBind($hostport);
	return unless ($ldap);

	return $ldap->schema();
	
}

sub handle {
	# XML contenente la richiesta #
	my $xml = shift; 

	# Faccio il parse per conoscere l'operazione
	# richiesta
	my $parser = new XML::Parser();
	$parser->setHandlers( Start => \&start,
                          End => \&end,
                          Char => \&char);
		
	$parser->parse($xml);
	# Oggetto contenente la richiesta
	my $dsml = GetRequest();
	
	for ($dsml->reqType) {
		/searchRequest/  and do doSearch($dsml);
		/modifyRequest/  and do doModify($dsml);
		/addRequest/     and do doAdd($dsml);
		/delRequest/     and do doDelete($dsml);
		/modDNRequest/   and do doModifyDN($dsml);
		/compareRequest/ and do doCompare($dsml);
	}
	GetResponse();	
}

sub doSearch {

	my $obj = shift;

	print Dumper($obj);
	
	my $hostname = $obj->reqAttrs->{host} || 'localhost';
	my $port     = $obj->reqAttrs->{port} || 389;
	my $base     = $obj->reqAttrs->{dn};
	
	my $scope;
	for ($obj->reqAttrs->{scope}) {
		/baseObject/   and do { $scope = 'base'; };
		/singleLevel/  and do { $scope = 'one';	};
		/wholeSubtree/ and do { $scope = 'sub'; };
		$scope = 'sub';
	}

	my $deref;
	for ($obj->reqAttrs->{derefAliases}) {
		/neverDerefAliases/   and do { $deref = 'never'; }; 
		/derefInSearching/    and do { $deref = 'search'; };
		/derefFindingBaseObj/ and do { $deref = 'find'; };
		/derefAlways/         and do { $deref = 'always'; };
		$deref = 'find';
	}
	my $sizeLimit = $obj->reqAttrs->{sizeLimit} || '0';

	my $attrs = $obj->attrsList || ['*'];
	my $filter = $obj->reqFilters || '(objectclass=*)';
	
	my $ldap = doBind($hostname.":".$port);	
	
	if ($ldap) {
		my $msg = $ldap->search( base      => $base,
		                         scope     => $scope,
					             attrs     => $attrs,
								 filter    => $filter,
								 deref     => $deref,
								 sizelimit => $sizeLimit );
		ErrorResponse($msg->error_name, $msg->error_text) 
			if ($msg->is_error());
		SearchReponse($msg) unless ($msg->is_error());
	}
}



sub doModify {

	my $obj = shift;
	print Dumper($obj) if ($debug);
	
	my $changes;
	
	my $hostname = $obj->reqAttrs->{host} || 'localhost';
	my $port     = $obj->reqAttrs->{port} || 389;
	my $dn       = $obj->reqAttrs->{dn};
	my $k = 0;
	
	foreach (@{$obj->reqElements}) {
		my $el;
		my %op;
#		$couples{$_->attrs->{name}} = $_->vals;
		$el->[0] = $_->attrs->{name};
		$el->[1] = $_->vals;
		my $oper = $_->attrs->{operation};
		$changes->[$k++] = $oper;
		$changes->[$k++] = $el;
	}
	
	my $ldap = doBind($hostname.":".$port, 'cn=admin,dc=lyra,dc=osd', 'pippo');	
	if (defined $ldap) {
		my $msg = $ldap->modify($dn, changes => $changes);
		ErrorResponse($msg->error_name, $msg->error_text) 
			if ($msg->is_error());
		GeneralResponse($obj->reqType, $msg->code, $msg->error_name)
			unless ($msg->is_error());
	}
}

sub doAdd {
	
	my $obj = shift;

	my $hostname = $obj->reqAttrs->{host} || 'localhost';
	my $port     = $obj->reqAttrs->{port} || 389;
	my $dn       = $obj->reqAttrs->{dn};

	print Dumper($obj) if ($debug);
	my $attrs;
	my $k = 0;
	foreach (@{$obj->reqElements}) {
		$attrs->[$k++] = $_->attrs->{name};
		$attrs->[$k++] = $_->vals;
	}
	my $ldap = doBind($hostname.":".$port, 'cn=admin,dc=lyra,dc=osd', 'pippo');	

	if (defined $ldap) {
		my $msg = $ldap->add($dn, attrs => $attrs);
		ErrorResponse($msg->error_name, $msg->error_text) 
			if ($msg->is_error());
		GeneralResponse($obj->reqType, $msg->code, $msg->error_name)
			unless ($msg->is_error());

	}

	
}

sub doDelete {

	my $obj = shift;
	
	my $hostname = $obj->reqAttrs->{host} || 'localhost';
	my $port     = $obj->reqAttrs->{port} || 389;
	my $dn       = $obj->reqAttrs->{dn};

	print Dumper($obj) if ($debug);
	my $ldap = doBind($hostname.":".$port, 'cn=admin,dc=lyra,dc=osd', 'pippo');	

	if (defined $ldap) {
		my $msg = $ldap->delete($dn);
		ErrorResponse($msg->error_name, $msg->error_text) 
			if ($msg->is_error());
		GeneralResponse($obj->reqType, $msg->code, $msg->error_name)
			unless ($msg->is_error());
	}
	

}

sub doModifyDN {

	my $obj = shift;
	
	my $hostname = $obj->reqAttrs->{host} || 'localhost';
	my $port     = $obj->reqAttrs->{port} || 389;
	my $dn       = $obj->reqAttrs->{dn};
	my $newrdn   = $obj->reqAttrs->{newrdn};
	my $delete   = ($obj->reqAttrs->{deleteoldrdn} eq 'true')? 1 : 0;
	my $newsup   = $obj->reqAttrs->{newSuperior};
	
	print Dumper($obj) if ($debug);
	my $ldap = doBind($hostname.":".$port, 'cn=admin,dc=lyra,dc=osd', 'pippo');	

	if (defined $ldap) {
		my $msg = $ldap->moddn($dn, newrdn       => $newrdn,
		                            deleteoldrdn => $delete,
									newsuperior  => $newsup);

		ErrorResponse($msg->error_name, $msg->error_text) 
			if ($msg->is_error());
		GeneralResponse($obj->reqType, $msg->code, $msg->error_name)
			unless ($msg->is_error());
	}

}

sub doCompare {
	my $obj = shift;
	my $hostname = $obj->reqAttrs->{host} || 'localhost';
	my $port     = $obj->reqAttrs->{port} || 389;
	my $dn       = $obj->reqAttrs->{dn};

	print Dumper($obj) if ($debug);
	
	my $element = $obj->reqElements->[0]; # ce n'è solo uno
	
	my $ldap = doBind($hostname.":".$port, 'cn=admin,dc=lyra,dc=osd', 'pippo');	
	
	if (defined $ldap) {
		my $msg = $ldap->compare($dn, attr  => $element->attrs->{name},
		                              value => $element->vals->[0]);
		ErrorResponse($msg->error_name, $msg->error_text) 
			if ($msg->is_error());
		GeneralResponse($obj->reqType, $msg->code, $msg->error_name)
			unless ($msg->is_error());
	}

}

# Ancora in test
# Il validator non supporta tutti gli
# elementi dell'xsd
sub validate {
	
	use XML::SAX::ParserFactory;
	use XML::Validator::Schema;
	
	my $xml = shift;
	my $validator = XML::Validator::Schema->new(file => $xsd);
	my $parser = XML::SAX::ParserFactory->parser(Handler => $validator);
	
	eval { $parser->parse_string($xml) };
	return "Error: File validation failed: $@" if $@;
	return 1;
	
}
	
1;

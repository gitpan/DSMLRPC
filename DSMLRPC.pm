package DSMLRPC;

require Exporter;

@ISA 	= qw(Exporter);
@EXPORT = qw(start end char 
             GetRequest GetResponse 
			 ErrorResponse SearchResponse GeneralResponse);

@EXPORT_OK = qw();

use strict;
use Data::Dumper;

use DSMLRPC::Request;
use DSMLRPC::Element;

$VERSION = '0.1'

# PARTI COMUNI DELLA RISPOSTA
my $batchResponse_open =  '<?xml version="1.0" encoding="UTF-8"?><batchResponse xmlns="urn:oasis:names:tc:DSML:2:0:core">';

my $batchResponse_close = '</batchResponse>';


# COSTANTI RELATIVI AGLI OPERATORI DEL FILTRO
# RAPPRESENTANO PIU O MENO LA BNF DELL'RFC 2254

my %OpFilter = (  'and'             => '&FILTERS',
                  'or'              => '|FILTERS',
                  'not'             => '!FILTER',
                  'greaterOrEqual'  => "(ATTR>=VAL)",
                  'lessOrEqual'     => "(ATTR<=VAL)",
                  'approxMatch'     => '(ATTR~=VAL)',
                  'equalityMatch'   => '(ATTR=VAL)',
                  'substrings'      => '(ATTR=',
                  'initial'         => 'VAL*)',
                  'final'           => '*VAL)',
                  'any'             => '*VAL*)',
                  'present'         => '(ATTR=*)',
                  'extensibleMatch' => 'NULL' );

# VARIABI GLOBALI

my $ReqTypes = { searchRequest   => ['filter', 'attribute'],  # Richiesta complessa
                 modifyRequest   => ['modification'],         # Richiesta semplice
                 addRequest      => ['attr'],                 # Richiesta semplice
                 delRequest      => [''],                     # Richiesta semplice
                 modDNRequest    => [''],                     # Richiesta semplice
                 compareRequest  => ['assertion'],            # Richiesta semplice
                 abandonRequest  => [''],
                 extendedRequest => ['NULL'] };

my $RespTypes = { modifyRequest   => '<modifyResponse>RESPONSE</modifyResponse>',         
				  addRequest      => '<addResponse>RESPONSE</addResponse>',                 
				  delRequest      => '<delResponse>RESPONSE</delResponse>',                     
				  modDNRequest    => '<modDNResponse>RESPONSE</modDNResponse>',
				  compareRequest  => '<compareResponse>RESPONSE</compareResponse>',            
				  abandonRequest  => [''] };



my $current;
my $reqType;
my $reqAttrs;
my $reqElements = undef;
my $reqFilters  = undef;
my $attrsList   = undef;

# Viene abilitato quando inizia una sezione
# relativa al filtro di una ricerca
my $FilterFlag = 0;

my @FilterStack = ();

my $elAttrs;
my $values;

my $DSMLrequest;
my $DSMLresponse;

sub start {

	my $p = shift;
    my $el = shift;
    my %attrs = @_;
	
	my $req = 0;
	
	if ($el eq 'extendedRequest') {
		$DSMLrequest = 'Errore: metodo non implementato!';
		return;
	}
	foreach (keys %$ReqTypes) {
		if ($_ eq $el) {
			$reqType = $_;
			$reqAttrs = \%attrs;
			$req = 1;
			last;
		}
	}	
	
	unless ($FilterFlag) {
		
		# Richiesta semplice
		if ($reqType ne 'searchRequest' && 
			$el eq $ReqTypes->{$reqType}->[0]) {
			# Salvo gli attributi dell'elemento della richiesta
			# Pulisco l'array dei valori
			$elAttrs = \%attrs;
			$values = [];
		}
		elsif ($el eq $ReqTypes->{$reqType}->[0]) {
			# Filtro
			$FilterFlag = 1;
			$reqFilters = '(';
		}
		elsif ($el eq $ReqTypes->{$reqType}->[1]) {
			# Attributi richiesta
			push @$attrsList, $attrs{'name'};
		}
	
	}
	else {
		# E mo' so' cazzi!
		my $filtercomp = undef;
		foreach (keys %OpFilter) {
  			if ($_ eq $el) {
				$filtercomp = $OpFilter{$_};
				last;
			}
		}
		if (exists $attrs{'name'}) { 
			$filtercomp =~ s/ATTR/$attrs{name}/; 
		}
		push @FilterStack, $filtercomp if ($filtercomp);
		
	}

	$current = $el;

}

sub end {

	my $p = shift;
	my $el = shift;
	
	
	# Richiesta semplice
	if ($reqType ne 'searchRequest' && 
		$el eq $ReqTypes->{$reqType}->[0]) {
		# OK creo un oggetto Element e lo
		# inserisco fra quelli della richiesta
		my $e = DSML::Element->new($elAttrs, $values);
		push @$reqElements, $e;
	}
	elsif ($el eq $ReqTypes->{$reqType}->[0]) {
		my $arg1;
		my $arg2;
		my $filter = '';
		while ($#FilterStack > 0) {
			if ($FilterStack[$#FilterStack] =~ /FILTER/) {
				$FilterStack[$#FilterStack] =~ s/FILTER$|FILTERS$/$filter/;
				$filter = '';
			}
			else {
				$arg2 = pop @FilterStack;
				if ($arg2 =~ /.+\)$/ && $arg2 !~ /^\(/) {
					$arg1 = pop @FilterStack;
					$filter .= $arg1.$arg2;
				}
				elsif ($arg2 =~ /^\(.+\)$/) {
					$filter .= $arg2;
				}
			}
		}
		if ($FilterStack[$#FilterStack] =~ /FILTER/) {
			$FilterStack[$#FilterStack] =~ s/FILTER$|FILTERS$/$filter/;
		}
		$reqFilters .= (pop @FilterStack).')';
		$FilterFlag = 0;
	}
	
	if ($el eq $reqType) {
		# Il parsing � finito 
		# Creo l'oggetto Request
		$DSMLrequest = DSML::Request->new($reqType, $reqAttrs, 
									      $reqElements, $reqFilters,
									      $attrsList);		
		
	}
	
}

sub char {
	
	my $p = shift;
	my @data = @_;
	
	unless ($FilterFlag) {
	
		if ($current eq 'value') {
			foreach (@data) {
				next if ($_ !~ /[A-Za-z0-9]/);
				push @$values, $_;
			}
		}
	
	}
	else {
		
		if ( $current eq 'value' ||
			 $current eq 'initial' ||
			 $current eq 'final' ) {
				my @vals;
				foreach (@data) {
					next if ($_ !~ /[A-Za-z0-9]/);
					push @vals, $_;
				}
				my $val = join " ",@vals;
				$FilterStack[$#FilterStack] =~ s/VAL/$val/;
		}
	
	}
}

sub GetRequest {
	return $DSMLrequest;
}

sub GetResponse {
	return $DSMLresponse;
}

sub ErrorResponse {
	my $name = shift;
	my $msg = shift;
	chomp($msg);	
	$DSMLresponse = $batchResponse_open;

	$DSMLresponse .= '<errorResponse type='.$name.'>';
	$DSMLresponse .= '<message>'.$msg.'</message>';
	$DSMLresponse .= '</errorResponse>';

	$DSMLresponse .= $batchResponse_close;
	
#	print $DSMLresponse;
#	return $DSMLresponse;
}


sub GeneralResponse {
	
	my $type = shift;
	my $code = shift;
	my $msg = shift;
	
	$DSMLresponse = $batchResponse_open . $RespTypes->{$type} . $batchResponse_close;
	
	$msg =~ tr/[A-Z]/[a-z]/;
	$msg =~ s/ldap_//;
	$DSMLresponse =~ s/RESPONSE/<resultCode code="$code" descr="$msg"\/>/;
	
}

sub SearchResponse {
    
	my $search = shift;

    my @entries = $search->sorted();

    $DSMLresponse = $batchResponse_open . "<searchResponse>\n";

    #my $searchopen = "<searchResultEntry>\n\t<dn>###DN###</dn>\n";
    my $searchopen = "<searchResultEntry dn=\"###DN###\">\n";
    my $searchclose = "</searchResultEntry>\n";

    #my $attr_open = "\t<attr>\n\t\t";
    my $attr_open = "\t<attr name=\"###NAME###\">\n\t\t";
    #my $attrname = "<name>###NAME###</name>\n\t\t";
    my $attr_value = "<value>###VAL###</value>\n\t";
    my $attr_close = "</attr>\n";

    foreach my $e (@entries) {

        my $open = $searchopen;
        my $dn = $e->dn();
        $dn =~ s/\&/\&amp;/;
        $open =~ s/###DN###/$dn/;

        $DSMLresponse .= $open;
        my $bin;
        foreach my $a ($e->attributes) {
            my $attr = $attr_open;
            $bin = 0;
            if ($a =~ /;binary/) {
                $bin = 1;
            }
			my $val = $e->get_value($a, asref=>1);
            foreach my $v (@$val) {
                $attr =~ s/###NAME###/$a/;
                $DSMLresponse .= $attr;

                my $value = $attr_value;

                if ($bin) {
                    my $enc = encode_base64($v);
                    $value =~ s/###VAL###/$enc/;
                }
                else {
                    $v =~ s/\&/\&amp;/;
                    $value =~ s/###VAL###/$v/;
                }
                $DSMLresponse .= $value;
                $DSMLresponse .= $attr_close;
            }
        }

        $DSMLresponse .= $searchclose;

    }

    $DSMLresponse .= "</searchResponse>\n" . $batchResponse_close;

    #return $DSMLresponse;
}

1;
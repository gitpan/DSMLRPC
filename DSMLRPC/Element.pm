package DSMLRPC::Element;


sub new {
	my $class = shift;

	my ($attrs, $val) = @_;

	my $self = { attrs => $attrs,
	             vals  => $val };
	
	bless $self, $class;
	return $self;
}


sub AUTOLOAD {
	my $obj = shift;
	my $meth = $AUTOLOAD;

	for ($meth) { 
		/attrs$/ and do {
			return $obj->{attrs};
		};
		/vals$/ and do {
			return $obj->{vals};
		};
		return 0;
	}
}

1;

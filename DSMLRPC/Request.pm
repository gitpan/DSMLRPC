package DSMLRPC::Request;

$VERSION = '0.1';
sub new {
	my $class = shift;
	my ($type, $attrs, $els, $fils, $list) = @_;

	my $self = { reqType	 => $type,
				 reqAttrs	 => $attrs,
				 reqElements => $els,
				 reqFilters	 => $fils,
				 attrsList   => $list};

	bless $self, $class;
	return $self;
	
}

sub AUTOLOAD {
	my $obj = shift;
    my $meth = $AUTOLOAD;

	for ($meth) {
		/reqType$/ and do {
			return $obj->{reqType};
		};
		/reqAttrs$/ and do {
			return $obj->{reqAttrs};
		};
		/reqElements$/ and do {
			return $obj->{reqElements};
		};
		/reqFilters$/ and do {
			return $obj->{reqFilters};
		};
		/attrsList$/ and do {
			return $obj->{attrsList};
		};
		return 0;
	}
}
																										

1;

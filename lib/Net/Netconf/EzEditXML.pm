package Net::Netconf::EzEditXML;

=head1 NAME

Net::Netconf::EzEditXML - Create XML for JUNOS XML API the Easy Way!

=head1 SYNOPSIS

 use Net::Netconf::EzEditXML;

 $newEzElem = new Net::Netconf::EzEditXML( [$elemName] );

 $ezElem->toString;
 $newEzElem = $ezElem->AUTOLOAD;
 $newEzElem = $ezElem->addPath( $path, [%pathChildren] );
 $newEzElem = $ezElem->newElement( $elemName, [$elemChildren] );
 $newEzElem = $ezElem->addElement( $elemName, [$elemChildren] );
 $newEzElem = $ezElem->addSibling( $sibName );
 $ezElem->setText( $newText );
 $ezElem->addXML( $xmlstring );
 $node = $ezElem->getLibNode;

=head1 DESCRIPTION

Net::Netconf::EzEditXML is used to create XML documents used for the purpose
of JUNOS device configuration and performing operational commands.
EzEditXML is a 'syntatic sugar wrapper' around the XML::LibXML
library.  EzEditXML does not communicate with the JUNOS target
devices.  That function is handled by the existing
Net::Netconf::Manager module.

=cut

use XML::LibXML;
require Exporter;
@ISA = qw(Exporter);

our $VERSION ='1.00';
=head1 METHODS

=cut

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: new
#-----------------------------------------------------------------------------
=over 4

=item new

=back

=over 2

$newEzElem = new Net::Netconf::EzEditXML( [$elemName] );

=back

=over 4

The B<< new >> constructor is used to create the top-level JUNOS XML
<configuration> element block.  If the $elemName is provided, then
this value will be used in place of 'configuration'.  This later case
can be used when creating XML operational commands.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################

sub new {

    my($class, $top) = @_;
    my $self = {};

    $self->{I_AM_NODE} = new XML::LibXML::Element(
	(($top)?$top:'configuration'));

    return bless $self;
}


###############################################################################
#-----------------------------------------------------------------------------
# METHOD: AUTOLOAD
#-----------------------------------------------------------------------------
###############################################################################

=over 4

=item AUTOLOAD

=back

=over 2

$newEzElem = $ezElem->I<< elemTag >>([ $children ]);

=back

=over 4

The EzEditXML B<< AUTOLOAD >> is used to either (a) dynamically create a new
element or (b) return an existing element.  In the case of (a) the
I<< elemTag >> block does not exist in the XML document and it is
created using the LibXML::Element underlying library.  If there are
$children passed to the new I<< elemTag >> then these children will be
added per the B<< addChildren >> method.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################

sub AUTOLOAD {

    my $subname = $AUTOLOAD;
    my $self = shift;
    my $e_self = $self->{I_AM_NODE};
    my $child = {};
    my $e_child;
    my $e_name;

    $subname =~ s/.*:://;
    return undef if ($subname eq "DESTROY");
    $subname =~ tr/_/-/;

    $e_name = $subname;

    # use the LibXML::findodes to locate the element name in the
    # exsting XML node and use it if it exists.
    #
    if( my (@nodes) = $e_self->findnodes( "./". $e_name ) ) {
	$e_child = shift @nodes;
	# ... for list items @nodes may contain many items (e.g. list
	# of interfaces in a vlan definition ... but e_child will be
	# the first one in the list fwiw.
    }
    # otherwise, create a new element and link it to the parent object
    #
    else {
	$e_child = new XML::LibXML::Element( $e_name );
	$self->{I_AM_NODE}->appendChild( $e_child );
    }

    # now bless the child into the EzEditXML class to allow for
    # further processing.

    $child->{I_AM_NODE} = $e_child;
    bless $child;

    # see if there are any remaining arguments passed to this
    # routine. if so add these children to the element

    $child->addChildren( @_ ) if( $#_ != -1 );

    return $child;
}

##############################################################################
##############################################################################
### --------------------------------------------------------------------------
### JUNOS specific attribute settings for the CLI capabilities
### 'activate', 'deactivate', 'insert', 'delete', and 'rename'
### --------------------------------------------------------------------------
##############################################################################
##############################################################################

sub junosDelete_E     { $_[0]->setAttribute('delete','delete') }
sub junosActivate_E   { $_[0]->setAttribute('active','active') }
sub junosDeactivate_E { $_[0]->setAttribute('inactive','inactive') }

sub junosDelete     { junosDelete_E( $_[0]->{I_AM_NODE} )}
sub junosActivate   { junosActivate_E( $_[0]->{I_AM_NODE} )}
sub junosDeactivate { junosDeactivate_E( $_[0]->{I_AM_NODE} )}

sub junosRename {
    my $self = shift;
    my $new_name = shift;
    $self->{I_AM_NODE}->setAttribute('rename','rename');
    $self->{I_AM_NODE}->setAttribute('name', $new_name);
}

sub junosInsert {
    my $self = shift;
    my $before_or_after = shift;
    my $ref_name = shift;
    $self->{I_AM_NODE}->setAttribute('insert',$before_or_after);
    $self->{I_AM_NODE}->setAttribute('name', $ref_name);
}

##############################################################################
##############################################################################
### --------------------------------------------------------------------------
### Generic XML utility routines
### --------------------------------------------------------------------------
##############################################################################
##############################################################################

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: newElement
#-----------------------------------------------------------------------------
=over 4

=item newElement

=back

=over 2

$newEzElem = newElement( $elemName, [$children] );

=back

=over 4

Create a new EzElement with the provided name, but does not attach it
to anything. If $children are provided, they are added per the B<<
addChildren >> method.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################


sub newElement {
    my ($class, $e_name, $children) = @_;
    my $self = {};

    $self->{I_AM_NODE} = new XML::LibXML::Element( $e_name );
    bless $self;

    $self->addChildren($children) if($children);

    return $self;
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: addElement
#-----------------------------------------------------------------------------
=over 4

=item addElement

=back

=over 2

$newEzElem = $ezElem->addElement( $elemName, [$elemChildren] );

=back

=over 4

This method needs to be documented.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################


sub addElement {
    my ($self, $elem, $children) = @_;

    my $ezE = (ref $elem)
	? $elem
	: newElement Net::Netconf::EzEditXML( $elem, $children );

    $self->{I_AM_NODE}->appendChild( $ezE->{I_AM_NODE} );

    return $ezE;
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: addPath
#-----------------------------------------------------------------------------
=over 4

=item addPath

=back

=over 2

$newEzElem = $ezElem->addPath( $path, [$children] );

=back

=over 4

This method needs to be documented.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################

sub addPath {

    my ($self,$path) = @_;
    my %elemHash = @_;

    my @dirs = split /\//, $path;
    my @ezElems = ();
    my $ezE;

    bless $self;

    # create elements for each directory level.  if the directory
    # level has associated subelements defined, then link them in now.

    foreach (@dirs) {
	$ezE = newElement Net::Netconf::EzEditXML( $_ );
	push @ezElems, $ezE;

	if($elemHash{$_}) {
	    $ezE->addChildren( $elemHash{$_} );
	}
    }

    # create parent/child relationship linkage on the path

    for (my $i=0; $i < $#ezElems; $i++) {
	$ezElems[$i]->addElement( $ezElems[$i+1] );
    }

    # add the complete structure to the calling object

    $self->addElement( $ezElems[0] );

    # return the first ezE in the path

    return $ezElems[0];
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: addChildren
#-----------------------------------------------------------------------------
=over 4

=item addChildren( $children );

=back

=over 2

$ezElem->addChildren( $textString );

=over 4

This version of addChildren is used to set the text-node value of the
calling element.

=back

$ezElem->addChildren( [{a=>b},{c=>d},{e=>y}, ...] );

=over 4

This version of addChildren is used to add unique child-elements as
defined in each hash {child-elem-name => child-text-value} reference.

=back

$ezElem->addChildren( [$s1, $s2, $s3, ...], [$options] );

=over 4

This version of addChildren is used to add a list of string-items all
with the same name as the parent $ezElem.  The $options can be:

=over 2

=item nameItems=>1

Include an addition <name> element block wihtin the $ezElem block.
Many of JUNOS configuration elements have a <name> element to unqiuely
identify multiple items of the same element type. The <interface> list
within a VLAN is a good example of this.

=item junosDelete=>1

Mark the item to be deleted from the configuration.

=item junosActivate=>1

Mark the item to be activated in the configuration.

=item junosDeactivate=>1

Mark the item to be deactivated in the configuration.

=back

=back

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################

sub addChildren {

    my $self = shift;
    my $argx = shift;

    my $e_self = $self->{I_AM_NODE};
    my %opts = @_;

    # ------------------------------------------------------------------------
    # There will always only be one arg of element data:
    # (a) <SCALAR>
    # (b) [{x=>y},{a=>b},...]
    # (c) [<SCALAR>,<SCALAR>,...]
    # ------------------------------------------------------------------------

    # ------------------------------------------------------------------------
    # CASE: <SCALAR>
    # ------------------------------------------------------------------------
    # If the argument is a SCALAR value, then use the value to set the
    # text-content for the e_child element.  For example, if the
    # e_child is the element block <host-name>, and the argument is
    # 'foo-baz', the resulting XML would be:
    # <host-name>foo-baz</host-name>

    if (not ref $argx) {
	$e_self->appendTextNode($argx );
	return;
    }

    # If it's not a SCALAR then it must be an ARRAY/ref; i.e. [...].
    # We don't accept any other arg types at this point.  So if it's
    # not an [], return now.

    return unless (ref($argx) eq "ARRAY");

    my $arefi = @$argx[0];  # see what the array is containing

    # ------------------------------------------------------------------------
    # CASE: [{x=>y},{a=>b},...]
    # ------------------------------------------------------------------------
    # If the [] contains a list of HASH/ref,
    # i.e. [{a=>b},{c=>d},{e=f}}], then create sub-elements in the
    # form of <key>value</key>.

    if (ref($arefi) eq "HASH") {

 	foreach (@$argx) {
 	    my ($key,$value) = each %{$_}; each %{$_};

	    my $e = new XML::LibXML::Element( $key );
	    junosDelete_E( $e ) if($opts{junosDelete});
	    junosActivate_E( $e ) if($opts{junosActivate});
	    junosDeactivate_E( $e ) if($opts{junosDeactivate});

	    $e->appendTextNode ($value);
	    $e_self->appendChild( $e );
 	}

	return;
    }

    # ------------------------------------------------------------------------
    # CASE: [<SCALAR>,<SCALAR>,...]
    # ------------------------------------------------------------------------
    # If the [] contains a list of SCALARs, i.e. ["x","y",z"], then we
    # are going to create elements of child foreach item in the [].
    #
    # So if child was <interface> and [] = ['ge-0/0/0', 'ge-0/0/1'],
    # then we would create:
    #   <interface>ge-0/0/0</interface>
    #   <interface>ge-0/0/1</interface>
    #
    # If the caller included 'nameItems=>1' in the args, then instead
    # of adding the text value for each child, add a child with
    # <name><items></name> for each child.  In the same example with
    # nameItems=>1, the result would be:
    #    <interface>
    #       <name>ge-0/0/0</name>
    #    </interface>
    #    <interface>
    #       <name>ge-0/0/1</name>
    #    </interface>

    my $self_name = $e_self->nodeName;
    my $e_parent = $e_self->parentNode;

    # this bit is added to handle the case of adding more same list
    # items. if the $self node has no children, then it's the first
    # time children are being added to the list.  in this case the we
    # need to remove the empty $self element that was automatically
    # created in the AUTOLOAD routine.
    #
    $e_parent->removeChild( $e_self ) if(not $e_self->hasChildNodes );

    while($arefi = shift @$argx) {
	my $e = new XML::LibXML::Element( $self_name );
	junosDelete_E( $e ) if($opts{junosDelete});
	junosActivate_E( $e ) if($opts{junosActivate});
	junosDeactivate_E( $e ) if($opts{junosDeactivate});
	if ($opts{nameItems}) {
	    $e->appendTextChild ('name', $arefi);
	}
	else {
	    $e->appendTextNode ($arefi);
	}
	$e_parent->appendChild( $e );
    }
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: addSibling
#-----------------------------------------------------------------------------
=over 4

=item addSibling

=back

=over 2

$newEzSibling = $ezElem->addSibling;

=back

=over 4

This method needs to be documented.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################

sub addSibling {

    my $self = shift;
    my $sib = {};

    $sib->{I_AM_NODE} = $self->{I_AM_NODE}->cloneNode;
    $self->{I_AM_NODE}->addSibling( $sib->{I_AM_NODE} );

    return bless $sib;
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: setText
#-----------------------------------------------------------------------------
=over 4

=item setText

=back

=over 2

$ezElem->setText( $newText );

=back

=over 4

This method will re-write the element's text-node value to $newText.
This method calls XML::LIbXML::Text->setData underlying method.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################

sub setText {
    my ($self, $text) = @_;
    my $e_self = $self->{I_AM_NODE};
    my $e_text = $e_self->firstChild;

    $e_text->setData( $text );

    return $self;
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: addXML
#-----------------------------------------------------------------------------
=over 4

=item addXML

=back

=over 2

$ezElem->addXML( $xmlstring );

=back

=over 4

This method accepts a "well-balanced-chunk" of XML string and
incorporates/attaches it into $ezElem.  This method calls the
XML::LibXML::Element->appendWellBalancedChunk method.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################

sub addXML {
    my ($self, $xmlstring) = @_;
    $self->{I_AM_NODE}->appendWellBalancedChunk( $xmlstring );
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: getLibNode
#-----------------------------------------------------------------------------
=over 4

=item getLibNode

=back

=over 2

$node = $ezElem->getLibNode;

=back

=over 4

This method returns the XML::LibXML node element.  The XML::LIbXML
library of routines can then be accesses.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################


sub getLibNode {
    my $self = shift;
    return $self->{I_AM_NODE}
}

###############################################################################
#-----------------------------------------------------------------------------
# METHOD: toString
#-----------------------------------------------------------------------------
=over 4

=item toString

=back

=over 2

$ezElem->toString

=back

=over 4

This method returns the XML document in string form.  It calls the
XML::LibXML underlying library to perform this action.

=back

=cut
#-----------------------------------------------------------------------------
###############################################################################


sub toString {
    my $self = shift;
    return $self->{I_AM_NODE}->toString(1);
}

package Koha::Plugin::Com::ByWaterSolutions::PayFeesByFile;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

use Koha::Patrons;
use Koha::Account::Lines;

use Text::CSV;
use IO::File;

use open qw(:utf8);

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Pay Fees by File',
    author          => 'Kyle M Hall',
    description     => 'This plugin accepts CSV files of the format "Fee Id/Cardnumber" or "Cardnumber/Amount to pay" and makes the appropriate payment',
    date_authored   => '2017-12-05',
    date_updated    => '1900-01-01',
    minimum_version => '17.05',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'tool' subroutine means the plugin is capable
## of running a tool. The difference between a tool and a report is
## primarily semantic, but in general any plugin that modifies the
## Koha database should be considered a tool
sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('payments') ) {
        $self->tool_step1();
    }
    else {
        $self->tool_step2();
    }

}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    return 1;
}

sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'tool-step1.tt' } );

    print $cgi->header();
    print $template->output();
}

sub tool_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'tool-step2.tt' } );

    my $filehandle = $cgi->upload('payments');
    my $comment = $cgi->param('comment');

    my $csv = Text::CSV_XS->new();

    my @lines;

    my $header = $csv->getline( $filehandle );
    while ( my $colref = $csv->getline($filehandle) ) {
        my $hr = {};
        for ( my $i = 0; $i < scalar @$header; $i++ ) {
            $hr->{ $header->[$i] } = $colref->[$i];
        }
        push( @lines, $hr );
    }

    if ( $lines[0]->{'Amount to Pay'} && $lines[0]->{Cardnumber} ) {
        #warn "Pay by Amount";
        foreach my $line (@lines) {
            my $cardnumber = $line->{Cardnumber};
            my $amount     = $line->{'Amount to Pay'};

            my $patron = Koha::Patrons->find( { cardnumber => $cardnumber } );

            if ($patron) {
                my $account = $patron->account;
                my $payment = $account->pay(
                    {
                        note   => $comment,
                        amount => $amount,
                    }
                );
                $line->{payment} = Koha::Account::Lines->find( $payment );
            }
            else {
                $line->{error} = 'Patron not found';
            }
        }
    }
    elsif ( $lines[0]->{'Fee ID'} && $lines[0]->{Cardnumber} ) {
        #warn "Pay by Fee ID";
        foreach my $line (@lines) {
            my $cardnumber      = $line->{Cardnumber};
            my $accountlines_id = $line->{'Fee ID'};

            my $patron = Koha::Patrons->find( { cardnumber => $cardnumber } );
            my $accountline = Koha::Account::Lines->find($accountlines_id);

            if ( !$patron ) {
                $line->{error} = 'Patron not found';
            }
            elsif ( !$accountline ) {
                $line->{error} = 'Fee not found!';
            }
            else {
                my $account = $patron->account;
                my $payment = $account->pay(
                    {
                        note   => $comment,
                        amount => $accountline->amountoutstanding,
                        lines  => [ $accountline ],
                    }
                );
                $line->{payment} = $payment;
            }
        }
    }
    else {
        #warn('Payment CSV file does not match a known format');
        $template->param(error => 'UNKNOWN_FORMAT');
    }

    #warn Data::Dumper::Dumper( \@lines );
    $template->param( lines => \@lines );

    print $cgi->header();
    print $template->output();
}


1;

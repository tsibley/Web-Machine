#!perl

use strict;
use warnings;

use Plack::Request;
use Plack::Response;
use Web::Machine::FSM;

=pod

Partial port of the webmachine example from here:

https://bitbucket.org/bryan/wmexamples/src/fa8104e75550/src/env_resource.erl

=cut

{
    package Env::Resource;
    use Moose;

    use JSON::XS ();

    with 'Web::Machine::Resource';

    my $JSON = JSON::XS->new->allow_nonref->pretty;

    sub _get_path {
        my $self = shift;
        my $var  = $self->request->path_info;
        $var =~ s/^\///;
        $var;
    }

    sub content_types_provided { [{ 'application/json' => 'to_json'   }] }
    sub content_types_accepted { [{ 'application/json' => 'from_json' }] }

    sub allowed_methods {
        return [
            qw[ GET HEAD PUT ],
            ((shift)->request->path_info eq '/'
                ? ()
                : 'DELETE')
        ];
    }

    sub resource_exists {
        my $self = shift;
        my $var  = $self->_get_path;
        if ( $var ) {
            if ( my $value = $ENV{ $var } ) {
                $self->context( $value );
            }
        }
        else {
            $self->context( { map { $_ => $ENV{ $_ } } keys %ENV } );
        }
    }

    sub to_json { $JSON->encode( (shift)->context ) }

    sub from_json {
        my $self = shift;
        my $var  = $self->_get_path;
        my $data = $JSON->decode( $self->request->content );
        if ( $var ) {
            $ENV{ $var } = $data;
        }
        else {
            map { $ENV{ $_ } = $data->{ $_ } } keys %$data;
        }
    }

    sub delete_resource {
        delete $ENV{ (shift)->_get_path };
    }
}

sub {
    Web::Machine::FSM->new->run(
        Env::Resource->new(
            request  => Plack::Request->new( shift ),
            response => Plack::Response->new,
        )
    )->finalize;
};

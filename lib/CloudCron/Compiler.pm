package CloudCron::Compiler;
use Moose;
use namespace::autoclean;

use CloudCron::Parser;
use Cfn;
use Cfn::Resource::AWS::Events::Rule;
use Cfn::Resource::Properties::AWS::Events::Rule;
use Path::Class;
use Carp;

has content => (is => 'ro', isa => 'Str', lazy => 1, default => sub {
    my $self = shift;
    croak 'Attribute file or content is required!' unless defined $self->file;
    Path::Class::file($self->file)->slurp;
});
has parser => (is => 'ro', isa => 'CloudCron::Parser', lazy => 1, builder => '_parser');
has file => (is => 'ro');

sub _parser {
    my $self = shift;
    return CloudCron::Parser->new({ content => $self->content });
}

sub rules {
    my $self = shift;

    die "Invalid crontab specification" if !$self->parser->is_valid;
    my @jobs = $self->parser->jobs;
    return map { $self->_as_rule($_); } @jobs;
}

sub envs {
    my $self = shift;
    return $self->parser->envs;
}

sub _as_rule {
    my $self = shift;
    my $job = shift;
    return Cfn::Resource::AWS::Events::Rule->new({
        Properties => $self->_get_properties($job),
    });
}

sub _cron {
    my $self = shift;
    my $job = shift;
    return join ' ', map { $job->$_->entity } qw/minute hour day month day_of_week/;
}

sub _get_properties {
    # Description no-req
    # EventPattern dont specify, specify schedule expresion instead
    # Name rule name, if not aws will specify a unique one
    # RoleArn no-req ?
    # ScheduleExpression req (cron) # support rate?
    # State no-req 'ENABLED'
    my $self = shift;
    my $job = shift;
    my $cron = $self->_cron($job);
    return Cfn::Resource::Properties::AWS::Events::Rule->new({
        Description => $job->command,
        #EventPattern => ,
        Name => $job->command,
        #RoleArn => ,
        ScheduleExpression => "cron($cron)",
        State => 'ENABLED',
        Targets => [
            { Arn => '', Id => "LineXXXTarget1", Input => '', InputPath => '{"command":[],"type":"shell"}' },
        ],
    });
}

__PACKAGE__->meta->make_immutable;
1;

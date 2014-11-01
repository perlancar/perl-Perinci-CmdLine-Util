package Perinci::CmdLine::Util;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(detect_perinci_cmdline_script);

our %SPEC;

$SPEC{detect_perinci_cmdline_script} = {
    v => 1.1,
    summary => 'Detect whether a file is a Perinci::CmdLine-based CLI script',
    description => <<'_',

The criteria are:

* the file must exist and readable;

* (optional, turned on by `filter_x`) file must have its executable mode bit
  set;

* content must start with a shebang C<#!>;

* content must contain something like `use Perinci::CmdLine`;

_
    args => {
        script => {
            summary => 'Path to file to be checked',
            req => 1,
            pos => 0,
        },
        include_nonexec => {
            summary => 'Include scripts that do not have +x mode bit set',
            schema  => 'bool*',
            default => 1,
        },
        include_backup => {
            summary => 'Include backup files',
            schema  => 'bool*',
            default => 0,
        },
        include_wrapper => {
            summary => 'Include wrapper scripts',
            description => <<'_',

A wrapper script is another Perl script, a shell script, or some other script
which wraps a Perinci::CmdLine script. For example, if `list-id-holidays` is a
Perinci::CmdLine script, then this shell script called `list-id-joint-leaves` is
a wrapper:

    #!/bin/bash
    list-id-holidays --is-holiday=0 --is-joint-leave=0 "$@"

It makes sense to provide the same completion for this wrapper script as
`list-id-holidays`.

To help this function detect such script, you need to put a tag inside the file:

    #!/bin/bash
    # TAG wrapped=list-id-holidays
    list-id-holidays --is-holiday=0 --is-joint-leave=0 "$@"

If this option is enabled, these scripts will be included.

_
            schema  => 'bool*',
            default => 0,
        },
    },
};
sub detect_perinci_cmdline_script {
    my %args = @_;

    my $script = $args{script} or return [400, "Please specify script"];
    my $exclude_backup = $args{exclude_backup} // 1;

    my $yesno = 0;
    my $reason = "";

  DETECT:
    {
        if ($exclude_backup && $script =~ /(~|\.bak)$/) {
            $reason = "Backup filename is excluded";
            last;
        }
        unless (-f $script) {
            $reason = "Not a file";
            last;
        };
        if ($args{filter_x} && !(-x _)) {
            $reason = "Not an executable";
            last;
        }
        my $fh;
        unless (open $fh, "<", $script) {
            $reason = "Can't be read";
            last;
        }
        read $fh, my($buf), 2;
        unless ($buf eq '#!') {
            $reason = "Does not start with a shebang (#!) sequence";
            last;
        }
        my $shebang = <$fh>;
        unless ($shebang =~ /perl/) {
            $reason = "Does not have 'perl' in the shebang line";
            last;
        }
        while (<$fh>) {
            if (/^\s*(use|require)\s+Perinci::CmdLine(|::Any|::Lite)/) {
                $yesno = 1;
                last DETECT;
            }
        }
        $reason = "Can't find any statement requiring Perinci::CmdLine ".
            "module family";
    }

    [200, "OK", $yesno, {"func.reason"=>$reason}];
}

1;
# ABSTRACT: Utility routines related to Perinci::CmdLine

=for Pod::Coverage ^(new)$

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<Perinci::CmdLine>

=cut

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

* (optional, if `include_noexec` is false) file must have its executable mode
  bit set;

* content must start with a shebang C<#!>;

* either: must be perl script (shebang line contains 'perl') and must contain
  something like `use Perinci::CmdLine`;

* or: a script tagged as a wrapper script and the wrapped script is a
  Perinci::CmdLine script.

_
    args => {
        script => {
            summary => 'Path to file to be checked',
            req => 1,
            pos => 0,
        },
        include_noexec => {
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
    my $include_noexec  = $args{include_noexec}  // 1;
    my $include_backup  = $args{include_backup}  // 0;
    my $include_wrapper = $args{include_wrapper} // 0;

    my $yesno = 0;
    my $reason = "";
    my %extra;

  DETECT:
    {
        if (!$include_backup && $script =~ /(~|\.bak)$/) {
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

        for my $alt (1..2) {
            # detect Perinci::CmdLine script
            {
                last unless $alt==1;
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
                $reason = "Can't find any statement requiring Perinci::CmdLine".
                    " module family";
            }
            # detect wrapper script
          DETECT_WRAPPER:
            {
                last unless $alt==2;
                last unless $include_wrapper;
                seek $fh, 0, 0;
                # XXX currently simplistic
                while (<$fh>) {
                    if (/^# TAG wrapped=([^=\s]+)\s*$/) {
                        require File::Which;
                        my $path = File::Which::which($1);
                        if (!$path) {
                            $reason = "Tagged as wrapper but ".
                                "wrapped program '$1' not found in PATH";
                            last DETECT_WRAPPER;
                        }
                        my $res = detect_perinci_cmdline_script(
                            script          => $path,
                            include_backup  => $include_backup,
                            include_noexec  => $include_noexec,
                            include_wrapper => 0, # currently not recursive
                        );
                        if ($res->[0] != 200 || !$res->[2]) {
                            $reason = "Tagged as wrapper but wrapped program ".
                                "'$1' is not a Perinci::CmdLine script";
                        }
                        $yesno = 1;
                        $reason = "Wrapper script for '$1'";
                        $extra{'func.is_wrapper'} = 1;
                        $extra{'func.wrapped'}    = $1;
                        last DETECT;
                    }
                }
                $reason = "Can't find wrapper tag";
            }
        } # for alt
    }

    [200, "OK", $yesno, {"func.reason"=>$reason, %extra}];
}

1;
# ABSTRACT: Utility routines related to Perinci::CmdLine

=for Pod::Coverage ^(new)$

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<Perinci::CmdLine>

=cut

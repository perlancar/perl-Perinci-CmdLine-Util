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

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Utility routines related to Perinci::CmdLine',
};

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

_
    args_rels => {
        req_one => [qw/filename string/],
    },
    args => {
        filename => {
            summary => 'Path to file to be checked',
            schema => 'str*',
            description => <<'_',

Either `filename` or `string` must be specified.

_
            pos => 0,
        },
        string => {
            summary => 'Path to file to be checked',
            schema => 'buf*',
            description => <<'_',

Either `file` or `string` must be specified.

_
        },
        include_noexec => {
            summary => 'Include scripts that do not have +x mode bit set',
            schema  => 'bool*',
            default => 1,
        },
    },
};
sub detect_perinci_cmdline_script {
    my %args = @_;

    (defined($args{filename}) xor defined($args{string}))
        or return [400, "Please specify either filename or string"];
    my $include_noexec  = $args{include_noexec}  // 1;

    my $yesno = 0;
    my $reason = "";

    my $meta = {};

    my $str = $args{string};
  DETECT:
    {
        if (defined $args{filename}) {
            my $fn = $args{filename};
            unless (-f $fn) {
                $reason = "'$fn' is not a file";
                last;
            };
            if (!$include_noexec && !(-x _)) {
                $reason = "'$fn' is not an executable";
                last;
            }
            my $fh;
            unless (open $fh, "<", $fn) {
                $reason = "Can't be read";
                last;
            }
            # for efficiency, we read a bit only here
            read $fh, $str, 2;
            unless ($str eq '#!') {
                $reason = "Does not start with a shebang (#!) sequence";
                last;
            }
            my $shebang = <$fh>;
            unless ($shebang =~ /perl/) {
                $reason = "Does not have 'perl' in the shebang line";
                last;
            }
            seek $fh, 0, 0;
            {
                local $/;
                $str = <$fh>;
            }
        }
        unless ($str =~ /\A#!/) {
            $reason = "Does not start with a shebang (#!) sequence";
            last;
        }
        unless ($str =~ /\A#!.*perl/) {
            $reason = "Does not have 'perl' in the shebang line";
            last;
        }
        if ($str =~ /^#\s*NO_PERINCI_CMDLINE_SCRIPT\s*$/m) {
            $reason = "Marked with # NO_PERINCI_CMDLINE_SCRIPT directive";
            last;
        }
        if ($str =~ /^\s*(use|require)\s+
                     (Perinci::CmdLine(|::Any|::Lite|::Classic))\b/mx) {
            $yesno = 1;
            $meta->{'func.module'} = $2;
            last DETECT;
        }
        if ($str =~ /^# PERICMD_INLINE_SCRIPT: (.+)/m) {
            $yesno = 1;
            $meta->{'func.module'} = 'Perinci::CmdLine::Inline';
            $meta->{'func.is_inline'} = 1;

            my $pericmd_inline_attrs = $1;
            my ($pericmd_inline_version) =
                $str =~ /Perinci::CmdLine::Inline version ([0-9._]+)/;
            $meta->{'func.notes'} //= [];
            $meta->{'func.pericmd_inline_version'} = $pericmd_inline_version;
            if (!$pericmd_inline_version) {
                push @{ $meta->{'func.notes'} },
                    "Can't detect version of Perinci::CmdLine::Inline version";
            }
            if ($pericmd_inline_version < 0.17) {
                push @{ $meta->{'func.notes'} }, join(
                    "",
                    "Won't parse # PERICMD_INLINE_SCRIPT attributes ",
                    "because prior to Perinci::CmdLine::Inline 0.17, ",
                    "the attributes are dumped as Perl instead of JSON ",
                    "so it's unsafe to parse",
                );
            } else {
                require JSON::MaybeXS;
                eval { $pericmd_inline_attrs =
                           JSON::MaybeXS::decode_json($pericmd_inline_attrs) };
                if ($@) {
                    push @{ $meta->{'func.notes'} },
                        "Can't parse # PERICMD_INLINE_SCRIPT attributes: $@";
                } else {
                    $meta->{'func.pericmd_inline_attrs'} =
                        $pericmd_inline_attrs;
                }
            }

            last DETECT;
        }
        $reason = "Can't find any statement requiring Perinci::CmdLine".
            " module family";
    } # DETECT

    $meta->{'func.reason'} = $reason;

    [200, "OK", $yesno, $meta];
}

1;
# ABSTRACT:

=for Pod::Coverage ^()$

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<Perinci::CmdLine>

=cut

#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper qw(Dumper);
use File::Temp   qw(tempfile);
use constant PARSE_ARG_EXPR => qr/^-{1,2}(.*)/;

our @lines;
our $debug          = grep { $_ =~ /^-{1,2}(.*)/ and $1 eq "debug" } @ARGV;
our $use_editor     = 0;
our @files_to_parse = ();

sub status {
    return @_ >> 8;
}

sub death {
    die "@_" . ( $debug ? "" : "\n" );
}

sub dbg {
    if ( not $debug ) {
        return;
    }

    warn "@_";
}

sub append_to_lines {
    my ($fh) = @_;
    $fh = *STDIN unless defined $fh;
    my $is_stdin = $fh eq *STDIN;

    while ( my $line = <$fh> ) {
        if ($is_stdin) { last unless $line =~ /\S/; }
        dbg "Appending: '$line'\n";
        push @lines, $line;
    }
}

sub spawn_editor {
    my $cmd = $ENV{"EDITOR"} // "vi";
    dbg "Will use cmd = '$cmd'\n";

    my ( $fh, $temp ) = tempfile(
        "yap-tmp-XXXXX",
        DIR    => File::Temp::tempdir( CLEANUP => 1 ),
        UNLINK => 1,
    );

    close $fh or death "Unable to create a temporary yapfile";

    if ( not( status system( $cmd, $temp ) ) ) {
        open( my $fh, "<", $temp )
          or death "Tried to yap undreadable file: $temp";
        append_to_lines $fh;
    }
    else {
        dbg "Editor exited with error\n";
        death;
    }

}

our %args = (
    "editor" => ( sub { $use_editor = 1; } ),
    "debug"  => ( sub { } )
);

sub parse_files {
    if ($use_editor) {
        death "Ambiguous parameters: tried to yap a file and use a text editor";
    }

    foreach my $file (@files_to_parse) {
        dbg "parsing $file\n";
        open( my $fh, "<", $file )
          or death "Tried to yap undreadable file: $file";
        append_to_lines $fh;
    }
}

sub parse_args {
    my $to_parse_file = 0;

    foreach (@ARGV) {
        if ( $_ =~ PARSE_ARG_EXPR and not $to_parse_file ) {
            if ( $_ eq "--" ) {
                $to_parse_file = 1;
                next;
            }

            if ( not exists $args{$1} ) {
                death "Unable to parse argument '$1'";
            }

            $args{$1}->();
            next;
        }

        push @files_to_parse, $_;
    }
}

sub from_stdin {
    @lines = ();
    append_to_lines;
}

sub parsed_lines {
    my %html_entities = (
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
        "'" => '&#39;',
    );

    for my $line (@lines) {
        $line =~ s/([&<>\"'])/$html_entities{$1}/g;
    }

    return @lines;
}

if ( !@ARGV or ( @ARGV == 1 and $debug ) ) {
    from_stdin;
}
else {
    parse_args;
    if (@files_to_parse) {
        parse_files;
    }

    if ($use_editor) {
        spawn_editor;
    }
}

print parsed_lines

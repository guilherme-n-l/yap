package Utils;

use strict;
use warnings;
use feature "state";
use Exporter;
use File::Temp qw(tempfile);
use URI::Find;
use Digest::SHA qw(sha256_hex);
use Time::Piece qw(localtime);

our @ISA = qw( Exporter );

our @EXPORT = qw(
  $use_editor
  $return_header
  $debug
  $output_file
  death
  dbg
);

our @EXPORT_OK = qw(
  $use_editor
  $return_header
  $debug
  $output_file
  death
  dbg
  from_editor
  from_stdin
  parse_args
  from_files
  encode_html
  header_of
);

use constant PARSE_ARG_EXPR => qr/^-{1,2}(.*)/;
use constant TEXT_WIDTH     => 80;
use constant HTML_STYLE => '<style>
    :root {
        --background-color-dark: #141414;
        --background-color-light: #ebebeb;
        --text-color-dark: #ebebeb;
        --text-color-light: #141414;
        --link-color: #4a90e2;
        --link-visited-color: #e94e77;
    }
    body { color: var(--text-color-dark); background-color: var(--background-color-dark); white-space: pre-wrap; margin: 0;}
    a { color: var(--link-color); }
    a:visited { color: var(--link-visited-color); }
</style>
';

our ( $title, $content );
our $debug         = grep { $_ =~ /^-{1,2}(.*)/ and $1 eq "debug" } @ARGV;
our $use_editor    = 0;
our $return_header = 0;
our %args          = (
    "editor" => ( sub { $use_editor    = 1; } ),
    "header" => ( sub { $return_header = 1; } ),
    "debug"  => ( sub { } ),
    "output" => (
        sub {
            my $filename = shift @_ // "default.html";
            dbg "Changing output to $filename\n";
            $output_file = open $output_file, ">", $filename
              or death "Could not write to file $filename: $!";
        }
    ),
);

sub status {
    @_ >> 8;
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

sub from_fh {
    my $fh = shift;
    $fh = *STDIN unless defined $fh;

    my $is_stdin    = $fh eq *STDIN;
    my $empty_count = 0;
    my @lines;

    while ( my $line = <$fh> ) {
        if ($is_stdin) {
            if ( $line !~ /\S/ ) { last if ++$empty_count == 2; }
            else                 { $empty_count = 0; }
        }
        chomp $line;
        dbg "Appending: '$line'\n";
        push @lines, $line;
    }

    return @lines;
}

sub from_editor {
    my $cmd = $ENV{"EDITOR"} // "vi";
    dbg "Will use cmd = '$cmd'\n";

    my ( $fh, $temp ) = tempfile(
        "yap-tmp-XXXXX",
        DIR    => File::Temp::tempdir( CLEANUP => 1 ),
        UNLINK => 1,
    );

    close $fh or death "Unable to create a temporary yapfile";

    my @lines;
    if ( not( status system( $cmd, $temp ) ) ) {
        open( my $fh, "<", $temp )
          or death "Tried to yap undreadable file: $temp";
        @lines = from_fh $fh;
    }
    else {
        dbg "Editor exited with error\n";
        death;
    }

    @lines;
}

sub from_stdin { from_fh; }

sub from_files {
    if ($use_editor) {
        death "Ambiguous parameters: tried to yap a file and use a text editor";
    }

    my @lines;
    foreach my $file (@_) {
        dbg "Parsing $file\n";

        open( my $fh, "<", $file )
          or death "Tried to yap undreadable file: $file";

        @lines = ( @lines, from_fh $fh );
    }

    @lines;
}

sub parse_args {
    my $to_parse_file = 0;
    my @files;

    foreach (@ARGV) {
        if ( $_ =~ PARSE_ARG_EXPR and not $to_parse_file ) {
            if ( $_ eq "--" ) {
                $to_parse_file = 1;
                next;
            }

            my $arg = $1;
            my ( $arg_name, @arg_values ) =
              $arg =~ /(.*)=(.*)/
              ? ( $1, split /,/, $2 )
              : ( $arg, () );

            exists $args{$arg_name} or death "Unable to parse argument '$arg'";
            $args{$arg_name}->(@arg_values);
            next;
        }

        push @files, $_;
    }

    @files;
}

sub line_wrap {
    my $line  = shift;
    my $width = TEXT_WIDTH;
    $line =~ s/(.{1,$width})(?:\s|$)|\S+/$1\n\t/g;
    $line =~ s/\n\t$//;
    $line;
}

sub linkify {
    state $finder = URI::Find->new(
        sub {
            my ( undef, $uri ) = @_;
            dbg "Found URL: $_\n";
            sprintf '<a href="%s">%s</a>', $uri, $uri;
        }
    );

    my $text = shift;
    $finder->find( \$text );
    $text;
}

sub encode_html {
    my %html_entities = (
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
        "'" => '&#39;',
    );

    my @lines = map {
        my $line = $_;
        $line =~ s/([&<>\"'])/$html_entities{$1}/g;
        $line;
    } @_;

    ( $title, $content ) =
      ( shift @lines, line_wrap join "\t\n", map { linkify $_ } @lines );

    dbg "Title: $title\n";
    dbg "Content: $content\n";

    my $style = HTML_STYLE;
    $style =~ s/^/\t/mg;

    "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"utf-8\">
    <title>$title</title>
$style
</head>
<body>
\t--- $title ---
\t$content
</body>
</html>\n";
}

sub fmt_today { localtime->ymd('-'); }

sub header_of {
    my $digest = sha256_hex shift;
    my $short  = substr $digest, 0, 6;
    my $date   = fmt_today();
    "<a href=\"./articles/$digest\">* $short ($date) -- $title</a>\n";
}

1;

__END__

=head1 NAME

Utils - Utility subroutines for the Yap CLI application

=head1 SYNOPSIS

  use Utils qw($use_editor $return_header $debug death dbg);
  use Utils qw(from_editor from_stdin parse_args from_files encode_html header_of);

  # Example: Parse arguments and process input
  my @files = parse_args();
  my @lines = @files ? from_files(@files) : $use_editor ? from_editor() : from_stdin();
  print encode_html(@lines);

=head1 DESCRIPTION

This module provides utility functions and variables for the Yap CLI application, which processes text input (from files, stdin, or an editor) and generates HTML output. It is designed for internal use by C<main.pl> and is not intended as a public library.

=head1 EXPORTED VARIABLES

=over

=item C<$use_editor>

Boolean flag indicating whether to use the user's editor (set by the C<--editor> flag). Defaults to 0.

=item C<$return_header>

Boolean flag indicating whether to return a header (set by the C<--header> flag). Defaults to 0.

=item C<$debug>

Boolean flag enabling debug output (set by the C<--debug> flag). Defaults to 0.

=item C<$title>

Stores the title of the processed content (set by C<encode_html>).

=item C<$content>

Stores the formatted content of the processed input (set by C<encode_html>).

=back

=head1 INTERNAL FUNCTIONS

=over

=item C<status(@args)>

Returns the exit status of a system command by shifting the exit code right by 8 bits.

=back

=head1 EXPORTED FUNCTIONS

=over

=item C<death(@msg)>

C<die> wrapper. In debug mode, prints out source-code line where C<death> occured.

=item C<dbg(@msg)>

Prints a debug message to STDERR if C<$debug> is true.

=item C<from_fh([$fh])>

Reads lines from a filehandle (defaults to STDIN). For STDIN, stops on two consecutive empty lines.

=item C<from_editor()>

Opens the user's editor (C<$ENV{EDITOR}> or C<vi>) to collect input via a temporary file.

=item C<from_stdin()>

Reads lines from STDIN, stopping on two consecutive empty lines.

=item C<from_files(@files)>

Reads lines from a list of files, ensuring C<$use_editor> is not set.

=item C<parse_args()>

Parses C<@ARGV> for flags (e.g., C<--editor>, C<--header>, C<--debug>) and returns a list of file names.

=item C<line_wrap($line)>

Wraps a line of text to C<TEXT_WIDTH> (80) characters, adding newlines and tabs.

=item C<linkify($text)>

Converts URLs in text to HTML C<< <a> >> tags using C<URI::Find>.

=item C<encode_html(@lines)>

Converts input lines to an HTML document, setting C<$title> (first line) and C<$content> (remaining lines, wrapped and linkified).

=item C<fmt_today()>

Returns the current date in YYYY-MM-DD format.

=item C<header_of($text)>

Generates an HTML anchor tag for a header using a SHA-256 digest, date, and C<$title>.

=back

=head1 CONSTANTS

=over

=item C<PARSE_ARG_EXPR>

Regular expression (C<qr/^-{1,2}(.*)/>) for parsing command-line flags.

=item C<TEXT_WIDTH>

Width for text wrapping (80 characters).

=item C<HTML_STYLE>

CSS style block for HTML output, defining colors and layout.

=back

=head1 AUTHOR

Guilherme Lima <acc.guilhermenl@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Guilherme Lima. This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

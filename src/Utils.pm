package Utils;

use strict;
use warnings;
use feature "state";
use Exporter;
use Data::Dumper qw(Dumper);
use File::Temp   qw(tempfile);
use URI::Find;
use Digest::SHA qw(sha256_hex);
use Time::Piece qw(localtime);

our @ISA = qw( Exporter );

our @EXPORT = qw(
  $use_editor
  $return_header
  $debug
  death
  dbg
);

our @EXPORT_OK = qw(
  $use_editor
  $return_header
  $debug
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
    "editor" => ( sub { $use_editor = 1; } ),
    "header" => ( sub { $return_header = 1 } ),
    "debug"  => ( sub { } ),
);

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
    my ( $lines_ref, $fh ) = @_;
    $fh = *STDIN unless defined $fh;

    my $is_stdin    = $fh eq *STDIN;
    my $empty_count = 0;

    while ( my $line = <$fh> ) {
        if ($is_stdin) {
            if ( $line !~ /\S/ ) { last if ++$empty_count == 2; }
            else                 { $empty_count = 0; }
        }
        chomp $line;
        dbg "Appending: '$line'\n";
        push @$lines_ref, $line;
    }
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
        append_to_lines \@lines, $fh;
    }
    else {
        dbg "Editor exited with error\n";
        death;
    }

    return @lines;

}

sub from_stdin {
    my @lines;
    append_to_lines \@lines;
    return @lines;
}

sub from_files {
    if ($use_editor) {
        death "Ambiguous parameters: tried to yap a file and use a text editor";
    }

    my @lines;
    foreach my $file (@_) {
        dbg "Parsing $file\n";

        open( my $fh, "<", $file )
          or death "Tried to yap undreadable file: $file";

        append_to_lines \@lines, $fh;
    }

    return @lines;
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

            if ( not exists $args{$1} ) {
                death "Unable to parse argument '$1'";
            }

            $args{$1}->();
            next;
        }

        push @files, $_;
    }

    return @files;
}

sub line_wrap {
    my $line  = shift;
    my $width = TEXT_WIDTH;
    $line =~ s/(.{1,$width})(?:\s|$)|\S+/$1\n\t/g;
    $line =~ s/\n\t$//;
    return $line;
}

sub linkify {
    state $finder = URI::Find->new(
        sub {
            my ( undef, $uri ) = @_;
            return sprintf '<a href="%s">%s</a>', $uri, $uri;
        }
    );

    my $text = shift;
    $finder->find( \$text );
    return $text;
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

package Utils;

use strict;
use warnings;
use feature "state";
use Exporter "import";
use File::Temp "tempfile";
use URI::Find;
use Digest::SHA "sha256_hex";
use Time::Piece "localtime";
use Text::Wrap;
use Scalar::Util "looks_like_number";
use HTML::Escape "escape_html";
use POD::Usage;

our @EXPORT = qw(
  parse_args
  from_input
  to_text
  wrap
  to_html_page
  header_of
  to_output
);

{
    no strict;
    use constant {
        PARSE_ARG_EXPR       => qr/^-{1,2}(.*)/,
        PARSE_ARG_PARTS_EXPR => qr/^-{1,2}([^=]*)(=(.*))?/,
        DEFAULT_TEXT_WIDTH   => 80,
        DEFAULT_OUTPUT_FILE  => Utils::DEFAULT_OUTPUT_FILE,
        HTML_PAGE_FORMAT     => qq|<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>%s</title>
<style>
:root {
    --background-color-dark: #141414;
    --background-color-light: #ebebeb;
    --text-color-dark: #ebebeb;
    --text-color-light: #141414;
    --link-color: #4a90e2;
    --link-visited-color: #e94e77;
}
body {
    color: var(--text-color-dark);
    background-color: var(--background-color-dark);
    white-space: pre-wrap;
    margin: 0;
}
a { color: var(--link-color); }
a:visited { color: var(--link-visited-color); }
</style>
</head>
<body>
\t--- %s ---

%s
</body>
</html>|,
    };
}

our %args;

sub death { die "@_" . ( $args{"editor"}{"value"} ? "" : "\n" ) }
sub yn    { shift ? "yes" : "no" }

sub dbg {
    return unless $args{"debug"}{"value"};
    warn "@_";
}

package Input {
    no strict;
    use constant {
        STD    => Input::STD,
        FILES  => Input::FILES,
        EDITOR => Input::EDITOR
    };
    our $value = STD;
    our @files;
};

package Output {
    no strict;
    use constant {
        STD       => Output::STD,
        DEFAULT   => Output::DEFAULT,
        SPECIFIED => Output::SPECIFIED
    };
    our $value = STD;
    our @header_files;
    our @files;
};

%args = (
    "editor" => {
        "handler" => sub {
            death "Cannot use --editor with files. Ambiguous argument: $_"
              if scalar @Input::files;
            $Input::value = Input::EDITOR;
            $args{"editor"}{"value"} = shift // $ENV{EDITOR};
        },
        "debug" => sub { $args{"editor"}{"value"} // "no" },
        "value" => undef
    },
    "header" => {
        "handler" => sub {
            @Output::header_files = @_;
            $args{"header"}{"value"} = 1;
        },
        "debug" => sub {
            my $out = yn $args{"header"}{"value"};
            $out .= sprintf " (%s)", join ", ", @Output::header_files
              if scalar @Output::header_files;
            $out;
        },
        "value" => 0,
    },
    "debug" => {
        "handler"  => sub { $args{"debug"}{"value"} = 1; },
        "debug"    => sub { yn $args{"debug"}{"value"} },
        "value"    => 0,
        "priority" => 9223372036854775807,
    },
    "output" => {
        "handler" => sub {
            @Output::files = @_;
            $Output::value =
              scalar @Output::files ? Output::SPECIFIED : Output::DEFAULT;
        },
        "debug" => sub {
            my $out = "$Output::value";
            $out .= sprintf " (%s)", join ", ", @Output::files
              if ( $Output::value eq Output::SPECIFIED );
            return $out;
        },
        "value" => *STDOUT,
    },
    "columns" => {
        "handler" => sub {
            $args{"columns"}{"value"} = shift;
            death "Must use number for columns, used: $args{'columns'}{'value'}"
              unless ( looks_like_number $args{"columns"}{"value"} );
            $args{"columns"}{"value"} = do {
                warn sprintf
                  "Used non-positive number for columns. Defaulting to %s",
                  DEFAULT_TEXT_WIDTH;
                DEFAULT_TEXT_WIDTH;
              }
              if ( $args{"columns"}{"value"} le 0 );
        },
        "debug" => sub {
            my $out = $args{"columns"}{"value"};
            $out .= " (default)" if $out eq DEFAULT_TEXT_WIDTH;
            $out;
        },
        "value" => DEFAULT_TEXT_WIDTH,
    },
    "help" => {
        "handler"  => sub { $args{"help"}{"value"} = 1; },
        "priority" => 9223372036854775806,
        "debug"    => sub { yn $args{"help"}{"value"} },
        "value"    => 0,
    }
);

sub from_stdin { *STDIN; }

sub from_files {
    map {
        open my $fh, "<", $_ or death "Tried to yap undreadable file: $_";
        $fh
    } @Input::files;
}

sub from_editor {
    my $editor = $args{"editor"}{"value"} or death "Unable to get editor";
    my ( $fh, $filename ) = tempfile(
        "yap-tmp-XXXXX",
        DIR    => File::Temp::tempdir( CLEANUP => 1 ),
        UNLINK => 1,
    );
    close $fh or death "Unable to close temp file";
    death "Unable to open editor: $!" if ( system $editor, $filename );
    open $fh, "<", $filename
      or death "Tried to yap undreadable file: $filename";
    $fh;
}

sub from_input {
    (
        {
            Input::STD    => \&from_stdin,
            Input::FILES  => \&from_files,
            Input::EDITOR => \&from_editor,
        }
    )->{$Input::value}->();
}

{
    no warnings 'redefine';

    sub wrap {
        state(undef) = $Text::Wrap::columns = $args{"columns"}{"value"};
        map { Text::Wrap::wrap "", "", $_ } @_;
    }
}

sub parse_args {
    my @argv     = scalar @_ ? @_ : @ARGV;
    my $end_args = 0;

    sub get_arg_name { shift =~ PARSE_ARG_PARTS_EXPR ? $1 : undef; }

    sub get_arg_values {
        shift =~ PARSE_ARG_PARTS_EXPR and defined $3 ? split /,/, $3 : ();
    }

    # Separate args from input files
    @argv = grep {
        sub {
            if ( not $end_args and $_ eq "--" ) {
                $end_args = 2;
                return 0;
            }
            unless ( $_ =~ PARSE_ARG_EXPR ) { $end_args |= 1 }
            elsif  ( not $end_args )        { return 1; }
            elsif  ( $end_args eq 1 ) {
                death "Arguments cannot be specified after files."
                  . " Invalid argument: $_";
            }
            elsif ( not $end_args and not exists $args{ get_arg_name($_) } ) {
                death "Invalid argument: $_";
            }

            # Set input files
            push @Input::files, $_;
            0;
          }
          ->($_)
    } @argv;

    # Sort by priority (desc.)
    @argv =
      sort {
        ( $args{ get_arg_name($b) }{"priority"} // 0 )
          <=> ( $args{ get_arg_name($a) }{"priority"} // 0 )
      } @argv;

    # Call handlers
    foreach (@argv) {
        $args{ get_arg_name($_) }{"handler"}->( get_arg_values($_) );
    }

    $Input::value = Input::FILES if ( scalar @Input::files );

    dbg join "\n\t", "Arguments used:",
      map { "$_ => " . $args{$_}{"debug"}->(); } keys %args;
    dbg join " ", "Input ($Input::value) from:",
      scalar @Input::files ? @Input::files : "*STDIN";

    Pod::Usage::pod2usage 2 if ( $args{"help"}{"value"} );
}

sub parse_links {
    state $finder = URI::Find->new(
        sub {
            my ( undef, $uri ) = @_;
            dbg "Found URL: $uri";
            $uri =~ s/&lt;/</g;
            $uri =~ s/&gt;/>/g;
            $uri =~ s/&amp;/&/g;
            $uri =~ s/&quot;/"/g;
            $uri =~ s;&#(\d+);;gex;
            sprintf '<a href="%s">%s</a>', $uri, $uri;
        }
    );

    my $text = shift;
    $finder->find( \$text );
    $text;
}

sub to_text {
    my ( $title, @lns );
    push @lns, "";
    foreach my $fh (@_) {
        while ( my $ln = <$fh> ) {
            chomp $ln;

            # Title is always non-empty first line
            unless ( defined $title ) {
                $title = $ln unless ( $ln eq "" );
                next;
            }
            if ( $ln eq "" and $lns[-1] ne "" ) {
                push @lns, "";
            }
            else {
                $lns[-1] .= $lns[-1] eq "" ? $ln : " $ln";
            }
        }
        close $fh unless ( fileno($fh) eq fileno(*STDIN) );
    }
    pop @lns if ( $lns[-1] eq "" );
    death "Nothing to yap about" unless ( defined $title );
    $title, @lns;
}

sub to_html_page {
    my ( $title, @lns ) = map { parse_links escape_html $_ } @_;
    @lns = map { $_ = $_ =~ s/\n/\n\t/gr; "\t$_" } @lns;
    sprintf HTML_PAGE_FORMAT . "\n", $title, $title, join "\n\n", @lns;
}

sub header_of {
    my ( $title, $page ) = @_;
    $title = escape_html $title;
    my $digest = sha256_hex $page;
    my $short  = substr $digest, 0, 6;
    my $date   = localtime->ymd('-');
    "<a href=\"./articles/$digest\">* $short ($date) -- $title</a>\n";
}

sub to_output {
    my ( $header, $page ) = @_;
    @Output::files = ( sha256_hex($page) . ".html" )
      if $Output::value eq Output::DEFAULT;

    sub get_fhs {
        my @files = @{ shift() };
        scalar @files
          ? map {
            open my $fh, ">", $_ or death "Tried to yap to unreadable file";
            $fh
          } @files
          : *STDOUT;
    }

    foreach ( [ \@Output::files, $page ], [ \@Output::header_files, $header ] )
    {
        my @fhs = get_fhs shift @$_;
        foreach my $fh (@fhs) {
            print $fh shift @$_;
            close $fh unless ( fileno $fh eq fileno STDOUT );
        }
    }
}

1;

__END__

=head1 NAME

Utils - Utility subroutines for the Yap CLI application

=head1 SYNOPSIS

  use Utils;

  # Example: Parse arguments and process input
  parse_args();
  my ($title, @lines) = to_text(from_input());
  my $html_page = to_html_page($title, @lines);
  to_output($html_page);

=head1 DESCRIPTION

This module provides utility functions and variables for the Yap CLI 
application, which processes text input (from files, stdin, or an editor) 
and generates HTML output. It is designed for internal use by C<main.pl> and 
is not intended as a public library.

=head1 INTERNAL FUNCTIONS

=over

=item C<death(@msg)>

C<die> wrapper. In debug mode, prints out the source-code line where 
C<death> occurred.

=item C<yn($value)>

Returns `"yes"` if the argument is true (non-zero), or `"no"` if the argument is false (zero or undefined).

  print yn(1);  # prints "yes"
  print yn(0);  # prints "no"

=item C<dbg(@msg)>

Prints a debug message to STDERR if C<$debug> is true.

=item C<from_stdin()>

Reads lines from STDIN.

=item C<from_files()>

Reads lines from a list of files. Raises an error if files cannot be opened.

=item C<from_editor()>

Opens the user's editor (C<$ENV{EDITOR}>) to collect input via a 
temporary file.

=item C<from_input()>

Determines the input source (STDIN, files, or editor) and retrieves the 
corresponding input.

=item C<wrap($line)>

Wraps a line of text to the column width specified by the C<--columns> 
argument (default 80 characters).

=item C<parse_args()>

Parses C<@ARGV> for flags (e.g., C<--editor>, C<--header>, C<--debug>) and 
processes input files.

=item C<to_text()>

Processes the input to a plain-text format, splitting lines and handling 
the first non-empty line as the title.

=item C<to_html_page()>

Converts the processed text to an HTML page, wrapping text and converting 
URLs to HTML links.

=item C<header_of($title, $page)>

Generates an HTML anchor tag for a header using a SHA-256 digest of the 
page, date, and title.

=item C<to_output($header, $page)>

Writes the header and page content to the specified output (default to 
STDOUT or specified files).

=back

=head1 AUTHOR

Guilherme Lima <acc.guilhermenl@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Guilherme Lima. This module is free software; you can 
redistribute it and/or modify it under the same terms as Perl itself.

=cut

#!/usr/bin/env -S perl -I.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use Utils;

our @lines;

if ( !@ARGV or ( @ARGV == 1 and $debug ) ) {
    @lines = Utils::from_stdin;
}
else {
    my @files = Utils::parse_args;

    if (@files) {
        @lines = Utils::from_files @files;
    }

    if ($use_editor) {
        @lines = Utils::from_editor;
    }
}

if ( not @lines ) {
    death "Nothing to yap about";
}

my $encoded = Utils::encode_html @lines;

print $return_header
  ? Utils::header_of $encoded
  : $encoded;

__END__

=head1 NAME

Yap - A command-line tool for converting text input to HTML

=head1 SYNOPSIS

    yap [--editor] [--header] [--debug] [file ...]
    yap [--debug] < input.txt
    yap --editor [--header] [--debug]

=head1 DESCRIPTION

Yap is a Perl-based command-line tool that converts text input into an HTML document. 
Input can come from files, standard input (STDIN), or a text editor. The first line of 
input is treated as the title, and the remaining lines are formatted as content with 
URLs converted to clickable links. Yap supports options to control input sources, output 
format, and debugging.

=head1 USAGE

Run the `yap` command with optional flags and input sources:

    yap [options] [file ...]

If no files or options are provided, Yap reads from STDIN until two consecutive empty 
lines are encountered. Use the `--editor` flag to input text via a text editor, or 
specify files to process their contents.

=head1 OPTIONS

=over 4

=item B<--editor>

Opens the text editor specified by the C<EDITOR> environment variable (defaults to 
C<vi>) to collect input. Cannot be used with file arguments.

Example:
    export EDITOR=nano
    yap --editor

=item B<--header>

Outputs an HTML anchor tag summarizing the content instead of the full HTML document. 
The header includes a SHA-256 digest of the content, the current date, and the title.

Example:
    yap --header input.txt

=item B<--debug>

Enables debug output, printing diagnostic messages to STDERR, such as parsed arguments, 
file operations, and processed lines.

Example:
    yap --debug input.txt

=item B<-->

Separates options from file arguments to allow processing files with names starting 
with dashes.

Example:
    yap --debug -- -file.txt

=back

=head1 INPUT SOURCES

Yap accepts input from one of the following sources:

=over 4

=item B<Standard Input (STDIN)>

If no files or C<--editor> is specified, Yap reads from STDIN. Input terminates after 
two consecutive empty lines.

Example:
    echo -e "My Title\nLine 1\nLine 2\n\n" | yap

=item B<Text Editor>

With the C<--editor> flag, Yap opens the editor defined in C<EDITOR> (e.g., C<vim>, 
C<nano>). Enter text, save, and exit the editor to process the input.

Example:
    yap --editor

=item B<Files>

Specify one or more files as arguments. Yap reads and processes their contents.

Example:
    yap file1.txt file2.txt

=back

=head1 OUTPUT

Yap generates an HTML document by default, with the following structure:

- The first line of input becomes the HTML C<< <title> >> and is displayed in the body.
- Remaining lines are wrapped to 80 characters, with URLs converted to clickable 
C<< <a> >> tags.
- A CSS style block defines colors and layout for dark and light themes.

If the C<--header> flag is used, Yap outputs a single HTML anchor tag with a SHA-256 
digest, the current date, and the title.

Example output (without C<--header>):
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <title>My Title</title>
        <style>
            :root { ... }
            body { ... }
            a { ... }
            a:visited { ... }
        </style>
    </head>
    <body>
        --- My Title ---
        Line 1 with http://example.com
        Line 2
    </body>
    </html>

Example output (with C<--header>):
    <a href="./articles/1a2b3c...">* 1a2b3c (2025-08-30) -- My Title</a>

=head1 ENVIRONMENT VARIABLES

=over 4

=item B<EDITOR>

Specifies the text editor to use with the C<--editor> flag. Defaults to C<vi> if unset.

Example:
    export EDITOR=nano

=back

=head1 EXAMPLES

1. Process text from STDIN:
    echo -e "My Post\nCheck out https://example.com\nAnother line" | yap > output.html

2. Use a text editor to create content:
    yap --editor > output.html

3. Process a file with debug output:
    yap --debug myfile.txt > output.html

4. Generate a header for a file:
    yap --header myfile.txt > header.html

5. Process multiple files:
    yap file1.txt file2.txt > combined.html

=head1 DIAGNOSTICS

Yap may terminate with an error message in the following cases:

- Invalid arguments (e.g., unknown flags): "Unable to parse argument 'flag'"

- Unreadable files: "Tried to yap unreadable file: filename"

- Using C<--editor> with file arguments: "Ambiguous parameters: tried to yap a file 
and use a text editor"

- No input provided: "Nothing to yap about"

- Editor or file operation failures: Descriptive error messages

In C<--debug> mode, additional diagnostic messages are printed to STDERR.

=head1 DEPENDENCIES

- Perl 5

- C<File::Temp>

- C<URI::Find>

- C<Digest::SHA>

- C<Time::Piece>

=head1 AUTHOR

Guilherme Lima <acc.guilhermenl@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 Guilherme Lima. This software is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl>, L<URI::Find>, L<Digest::SHA>, L<File::Temp>, L<Time::Piece>

=cut

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

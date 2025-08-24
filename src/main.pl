#!/usr/bin/perl

use strict;
use warnings;
use lib qw(.);
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

if (not @lines) {
    death "Nothing to yap about";
}
print Utils::encode_html @lines

#!perl

use strict;
use warnings;
use utf8;
use Test::More tests => 13 * 2;
use Text::Amuse::Preprocessor;
use File::Temp;
use File::Spec::Functions qw/catfile catdir/;

my $builder = Test::More->builder;
binmode $builder->output,         ":encoding(UTF-8)";
binmode $builder->failure_output, ":encoding(UTF-8)";
binmode $builder->todo_output,    ":encoding(UTF-8)";


my $input = <<'INPUT';
U+FB00	ﬀ	ef ac 80	LATIN SMALL LIGATURE FF       ﬀ
U+FB01	ﬁ	ef ac 81	LATIN SMALL LIGATURE FI       ﬁ
U+FB02	ﬂ	ef ac 82	LATIN SMALL LIGATURE FL       ﬂ
U+FB03	ﬃ	ef ac 83	LATIN SMALL LIGATURE FFI      ﬃ
U+FB04	ﬄ	ef ac 84	LATIN SMALL LIGATURE FFL      ﬄ
INPUT

my $expected = <<'OUT';
U+FB00    ff    ef ac 80    LATIN SMALL LIGATURE FF       ff
U+FB01    fi    ef ac 81    LATIN SMALL LIGATURE FI       fi
U+FB02    fl    ef ac 82    LATIN SMALL LIGATURE FL       fl
U+FB03    ffi    ef ac 83    LATIN SMALL LIGATURE FFI      ffi
U+FB04    ffl    ef ac 84    LATIN SMALL LIGATURE FFL      ffl
OUT

test_strings(ligatures => $input, $expected);

test_strings(missing_nl => "hello\nthere", "hello\nthere\n");

test_strings('garbage',
             "hello ─ there hello ─ there\r\n\t",
             "hello — there hello — there\n    \n");

test_strings('ellipsis_no_fix',
             ". . . test... . . . but here .  .  .  .",
             ". . . test... . . . but here .  .  .  .");


test_strings('ellipsis',
             ". . . test... . . . but here .  .  .  .",
             "... test...... but here .  .  .  .", 1, 1, 0);


$input =<<'INPUT';
https://anarhisticka-biblioteka.net/library/

<br>http://j12.org/spunk/ http://j12.org/spunk/<br>http://j12.org/spunk/

<br>https://anarhisticka-biblioteka.net/library/erik-satie-depesa<br>https://anarhisticka-biblioteka.net/library/erik-satie-depesa

[[http://j12.org/spunk/][j12.org]]<br>[[http://j12.org/spunk/][j12.org]]

[[https://anarhisticka-biblioteka.net/library/erik-satie-depesa][anarhisticka-biblioteka.net]]<br>[[https://anarhisticka-biblioteka.net/library/erik-satie-depesa][anarhisticka-biblioteka.net]]

http://en.wiktionary.org/wiki/%EF%AC%85

http://en.wikipedia.org/wiki/Pi_%28disambiguation%29

http://en.wikipedia.org/wiki/Pi_%28instrument%29

(http://en.wikipedia.org/wiki/Pi_%28instrument%29)

as seen in http://en.wikipedia.org/wiki/Pi_%28instrument%29.

as seen in http://en.wikipedia.org/wiki/Pi_%28instrument%29 and (http://en.wikipedia.org/wiki/Pi_%28instrument%29).
INPUT

$expected =<<'OUTPUT';
[[https://anarhisticka-biblioteka.net/library/][anarhisticka-biblioteka.net]]

<br>[[http://j12.org/spunk/][j12.org]] [[http://j12.org/spunk/][j12.org]]<br>[[http://j12.org/spunk/][j12.org]]

<br>[[https://anarhisticka-biblioteka.net/library/erik-satie-depesa][anarhisticka-biblioteka.net]]<br>[[https://anarhisticka-biblioteka.net/library/erik-satie-depesa][anarhisticka-biblioteka.net]]

[[http://j12.org/spunk/][j12.org]]<br>[[http://j12.org/spunk/][j12.org]]

[[https://anarhisticka-biblioteka.net/library/erik-satie-depesa][anarhisticka-biblioteka.net]]<br>[[https://anarhisticka-biblioteka.net/library/erik-satie-depesa][anarhisticka-biblioteka.net]]

[[http://en.wiktionary.org/wiki/%EF%AC%85][en.wiktionary.org]]

[[http://en.wikipedia.org/wiki/Pi_%28disambiguation%29][en.wikipedia.org]]

[[http://en.wikipedia.org/wiki/Pi_%28instrument%29][en.wikipedia.org]]

([[http://en.wikipedia.org/wiki/Pi_%28instrument%29][en.wikipedia.org]])

as seen in [[http://en.wikipedia.org/wiki/Pi_%28instrument%29][en.wikipedia.org]].

as seen in [[http://en.wikipedia.org/wiki/Pi_%28instrument%29][en.wikipedia.org]] and ([[http://en.wikipedia.org/wiki/Pi_%28instrument%29][en.wikipedia.org]]).
OUTPUT

my $original_input = $input;
my $original_expected = $expected;

test_strings(links => $input, $expected, 0, 1, 0);

foreach my $lang (qw/en fi es sr hr ru it mk/) {
    test_lang($lang);
}

sub test_lang {
    my $lang = shift;
    my $input = "#lang $lang\n\n" . read_file(catfile(qw/t testfiles infile.muse/));
    my $expected = read_file(catfile(qw/t testfiles/, "$lang.muse"));
    test_strings($lang, $input, $expected, 1, 1, 0);
}

sub test_strings {
    my ($name, $input, $expected, $typo, $links, $fn) = @_;

    my $input_string = $input;
    my $output_string = '';

    my $pp = Text::Amuse::Preprocessor->new(input => \$input_string,
                                            output => \$output_string,
                                            fix_links => $links,
                                            fix_typography => $typo,
                                            fix_footnotes => $fn,
                                           );
    $pp->process;
    is_deeply([ split /\n/, $output_string ],
              [ split /\n/, $expected ],
              "$name with reference works");
    
    # and the file variant
    my $dir = File::Temp->newdir(CLEANUP => 1);
    my $wd = $dir->dirname;
    my $infile = catfile($wd, 'in.muse');
    my $outfile = catfile($wd, 'out.muse');
    diag "Using $wd for $name";
    write_file($infile, $input);

    my $pp_file = Text::Amuse::Preprocessor->new(input => $infile,
                                                 output => $outfile,
                                                 fix_links => $links,
                                                 fix_typography => $typo,
                                                 fix_footnotes => $fn,
                                                );
    $pp_file->process;
    is_deeply([ split /\n/, read_file($outfile) ],
              [ split /\n/, $expected ],
              "$name with files works");
}

sub read_file {
    return Text::Amuse::Preprocessor->_read_file(@_);
}

sub write_file {
    return Text::Amuse::Preprocessor->_write_file(@_);
}


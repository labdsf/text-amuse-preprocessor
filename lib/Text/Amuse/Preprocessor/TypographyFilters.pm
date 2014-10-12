package Text::Amuse::Preprocessor::TypographyFilters;

use strict;
use warnings;
use utf8;
# use Encode;

=encoding utf8

=head1 NAME

Text::Amuse::Preprocessor::TypographyFilters - Text::Amuse::Preprocessor's filters

=head1 DESCRIPTION

Used internally by L<Text::Amuse::Preprocessor>.

=head1 FUNCTIONS

=head2 linkify($string);

Activate links in $string and returns it.

=cut

sub linkify {
    my $l = shift;
    return unless defined $l;
    $l =~ s{(?<!\[) # be sure not to redo the same thing, looking behind
            ((https?:\/\/) # protocol
                (\w[\w\-\.]+\.\w+) # domain
                (\:\d+)? # the port
                (/ # a slash
                    [^\[<>\s]* # everything that is not a space, a < > and a [
                    [\w/] # but end with a letter or a slash
                )?
            )
            (?!\]) # and look around
       }{[[$1][$3]]}gx;
    return $l;
}


=head2 characters

Return an hashref where keys are the language codes, and the values an
hashref with the definition of punctuation characters. Each of them
has the following keys: C<ldouble>, C<rdouble>, C<lsingle>,
C<rsingle>, C<apos>, C<emdash>, C<endash>.

=cut

# EM-DASH: 2014
# EN-DASH: 2013

sub characters {
    return {
            en => {
                   ldouble => "\x{201c}",
                   rdouble => "\x{201d}",
                   lsingle => "\x{2018}",
                   rsingle => "\x{2019}",
                   apos => "\x{2019}",
                   emdash => "\x{2014}",
                   endash => "\x{2013}",
                   dash =>    "\x{2014}",
                  },
            es => {
                   ldouble => "\x{ab}",
                   rdouble => "\x{bb}",
                   lsingle => "\x{2018}",
                   rsingle => "\x{2019}",
                   apos => "\x{2019}",
                   emdash => "\x{2014}",
                   endash => "-",
                   dash =>    "\x{2014}",
                  },
            fi => {
                   ldouble => "\x{201d}",
                   rdouble => "\x{201d}",
                   lsingle => "\x{2019}",
                   rsingle => "\x{2019}",
                   apos => "\x{2019}",
                   # finnish uses short dash
                   emdash => "\x{2013}",
                   endash => "-",
                   dash =>    "\x{2013}",
                  },
            sr => {
                   #  „članak o ’svicima’“
                   ldouble => "\x{201e}",
                   rdouble => "\x{201c}",
                   lsingle => "\x{2019}",
                   rsingle => "\x{2019}",
                   apos =>    "\x{2019}",
                   # serbian uses short dash.
                   emdash =>  "\x{2013}",
                   endash =>  "\x{2013}",
                   dash =>    "\x{2014}",
                  },
            hr => {
                   # http://pravopis.hr/pravilo/navodnici/71/ „...” i »...«.
                   ldouble => "\x{201e}",
                   rdouble => "\x{201d}",
                   # http://pravopis.hr/pravilo/polunavodnici/73/ ‘...’
                   lsingle => "\x{2018}",
                   rsingle => "\x{2019}",
                   apos => "\x{2019}",
                   # croatian uses short dash:
                   # http://pravopis.hr/pravilo/crtica/69/
                   emdash =>  "\x{2013}",
                   endash =>  "\x{2013}",
                   dash =>    "\x{2014}",
                  },
            ru => {
                   ldouble => "\x{ab}",
                   rdouble => "\x{bb}",
                   lsingle => "\x{2018}",
                   rsingle => "\x{2019}",
                   apos    => "\x{2019}",
                   emdash  => "\x{2014}",
                   endash  => "-",
                   dash    => "\x{2014}",
                  },
            it => {
                   ldouble => "\x{201c}",
                   rdouble => "\x{201d}",
                   lsingle => "\x{2018}",
                   rsingle => "\x{2019}",
                   apos    => "\x{2019}",
                   emdash  => "\x{2013}",
                   endash  => "-",
                   dash    => "\x{2014}",
                  },
            # Macedonian 	„…“ 	’…‘
            mk => {
                   ldouble => "\x{201e}",
                   rdouble => "\x{201c}",
                   lsingle => "\x{2019}",
                   rsingle => "\x{2018}",
                   apos    => "\x{2019}",
                   emdash  => "\x{2013}",
                   endash  => "\x{2013}",
                   dash    => "\x{2014}",
                  },
           };
}


=head2 specific_filters

Return an hashref where the key is the language codes and the value a
subroutine to filter the line.

Here we put the routines which can't be abstracted away in a
language-indipendent fashion.

=cut

sub _english_specific {
    my $l = shift;
    $l =~ s!\b(\d+)(th|rd|st|nd)\b!$1<sup>$2</sup>!g;
    return $l;
}

sub specific_filters {
    return {
            en => \&_english_specific,
           };
}

=head2 specific_filter($lang)

Return the specific filter for lang, if present.

=cut

sub specific_filter {
    my ($lang) = @_;
    return unless $lang;
    return specific_filters->{$lang};
}

=head2 filter($lang)

Return a sub for the typographical fixes for the language $lang.

=cut


sub filter {
    my ($lang) = @_;
    return unless $lang;
    my $all = characters();
    my $chars = $all->{$lang};
    return unless $chars;

    # copy to avoid typos
    my $ldouble = $chars->{ldouble} or die;
    my $rdouble = $chars->{rdouble} or die;
    my $lsingle = $chars->{lsingle} or die;
    my $rsingle = $chars->{rsingle} or die;
    my $apos =    $chars->{apos}    or die;
    my $emdash =  $chars->{emdash}  or die;
    my $endash =  $chars->{endash}  or die;
    my $dash    = $chars->{dash}    or die;
    my $filter = sub {
        my $l = shift;

        # TODO
        # if there is nothing to do, speed up.
        # return $l unless $l =~ /['"`-]/;

        # first, consider `` and '' opening and closing doubles
        $l =~ s/``/$ldouble/g;

        $l =~ s/`/$lsingle/g;

        # but set it as ", we'll replace that later
        $l =~ s/''/"/g;

        # beginning of the line, long dash
        $l =~ s/^-(?=\s)/$dash/;

        # between spaces, just replace
        $l =~ s/(?<=\S)(\s+)-{1,3}(\s+)(?=\S)/$1$emdash$2/g;

        # -word and word-, in the middle of a line
        $l =~ s/(?<=\S)(\s+)-(\w.+?\w)-(?=\s)/$1$emdash $2 $emdash/g;

        # an opening before two digits *probably* is an apostrophe.
        # Very common case.
        $l =~ s/'(?=\d\d\b)/$apos/g;

        # if it touches a word on the right, and on the left there is not a
        # word, it's an opening quote
        $l =~ s/(?<=\W)"(?=\w)/$ldouble/g;
        $l =~ s/(?<=\W)'(?=\w)/$lsingle/g;

        # if there is a space at the left, it's opening
        $l =~ s/(?<=\s)"/$ldouble/g;
        $l =~ s/(?<=\s)'/$lsingle/g;

        # beginning of line, opening
        $l =~ s/^"/$ldouble/;
        $l =~ s/^'/$lsingle/;

        # print encode('UTF-8', "**** $l");

        # apostrophes, between non-white material, probably
        $l =~ s/(?<=\w)'(?=\w)/$apos/g;

        # print encode('UTF-8', "**** $l");

        # or before a left quote
        $l =~ s/(?<=\w)'(\Q$lsingle\E)/$apos$1/g;
        $l =~ s/(?<=\w)'(\Q$ldouble\E)/$apos$1/g;

        # print encode('UTF-8', "**** $l");

        # word at the left, closing
        $l =~ s/(?<=\w)"(?=\W)/$rdouble/g;
        $l =~ s/(?<=\w)'(?=\W)/$rsingle/g;


        # the others are right quotes, hopefully
        $l =~ s/"/$rdouble/gs;
        $l =~ s/'/$rsingle/g;

        # replace with an endash, but only if between digits and not
        # in the middle of something
        $l =~ s/(?<![\-\/])\b(\d+)-(\d+)\b(?![\-\/])/$1$endash$2/g;

        return $l;
    };
    return $filter;
}

sub _nbsp_filters {
    return { ru => \&_ru_nbsp_filter };
}

sub _nbsp_specs {
    return {
            # to read: add a space ...
            ru => {
                   before_words => [
                                    "\x{2013}", "\x{2014}", "\x{2212}",
                                    "б", "ж", "ли", "же", "ль", "бы", "бы,", "же",
                                   ],
                   after_digit_before_words => [
                                                "января", "февраля",
                                                "марта", "апреля",
                                                "мая", "июня", "июля",
                                                "августа", "сентября",
                                                "октября", "ноября",
                                                "декабря", "г", "кг",
                                                "мм", "дм", "см", "м",
                                                "км", "л", "В", "А",
                                                "ВТ", "W", "°C",
                                               ],
                   after_words => [
                                   "в", "к", "о", "с", "у",
                                   "В", "К", "О", "С", "У",
                                   "на", "от", "об", "из", "за", "по", "до", "во",
                                   "та", "ту", "то", "те", "ко", "со",
                                   "На", "От", "Об", "Из", "За", "По", "До", "Во",
                                   "Ко", "Та", "Ту", "То", "Те", "Со",
                                   "А", "А,", "а", "а,",
                                   "И", "И,", "и", "и,",
                                   "но", "но,", "Но", "Но,",
                                   "да", "да,", "Да", "Да,",
                                   "не", "ни",  "Не", "Ни",
                                   "ну", "ну,", "Ну", "Ну,",
                                   "с.", "ч.",  "см.", "См.",
                                   "им.", "Им.","т.", "п."
                                  ]
                  },
           };
}

=head2 nbsp_filter($lang)

Return a sub (if the filter exists) to place non-breaking spaces in
language-specific places.

=cut

sub nbsp_filter {
    my ($lang) = @_;
    return unless $lang;
    my $specs = _nbsp_specs()->{$lang};
    return unless $specs;
    my @before_words             = @{ $specs->{before_words}             };
    my @after_digit_before_words = @{ $specs->{after_digit_before_words} };
    my @after_words              = @{ $specs->{after_words}              };
    return unless (@before_words || @after_digit_before_words || @after_words);
    # TODO: convert the list in qr//, probably we get a speed up
    return sub {
        my $l = shift;
        foreach my $token (@before_words) {
            $l =~ s/(?<=\S)
                    \s+
                    \Q$token\E
                    (?=\W)
                   /\x{a0}$token/gx;
        }
        foreach my $token (@after_digit_before_words) {
            $l =~ s/(?<=\d)
                    \s+
                    \Q$token\E
                    (?=\W)
                   /\x{a0}$token/gx;
        }
        foreach my $token (@after_words) {
            $l =~ s/\b
                    \Q$token\E
                    \s+
                    (?=\S)
                   /$token\x{a0}/gx;
        }
        return $l;
    };
}



1;

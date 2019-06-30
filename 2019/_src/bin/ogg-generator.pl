#!/usr/bin/env perl
#
use 5.010;
use strict;
use warnings;
use Image::Magick;
use Data::Dumper;

my $image = Image::Magick->new(size=>'960x462',pointsize=>30,stroke=>'white',fill=>'white',);
sub Wrap
{
   my ($text, $img, $maxwidth) = @_;

   # figure out the width of every character in the string
   #
   my %widths = map(($_ => ($img->QueryFontMetrics(text=>$_))[4]),
      keys %{{map(($_ => 1), split //, $text)}});
   die Dumper(\%widths);
   my (@newtext, $pos);
   for (split //, $text) {
     # print "$pos\n";
      # check to see if we're about to go out of bounds
      if ($widths{$_} + $pos > $maxwidth) {
         $pos = 0;
         my @word;
         # if we aren't already at the end of the word,
         # loop until we hit the beginning
         if ( $newtext[-1] ne " "
              && $newtext[-1] ne "-"
              && $newtext[-1] ne "\n") {
            unshift @word, pop @newtext
               while ( @newtext && $newtext[-1] ne " "
                       && $newtext[-1] ne "-"
                       && $newtext[-1] ne "\n")
         }

         # if we hit the beginning of a line,
         # we need to split a word in the middle
         if ($newtext[-1] eq "\n" || @newtext == 0) {
            push @newtext, @word, "\n";
         } else {
            push @newtext, "\n", @word;
            $pos += $widths{$_} for (@word);
         }
      }
      push @newtext, $_;
      $pos += $widths{$_};
      $pos = 0 if $newtext[-1] eq "\n";
   }

   return join "", @newtext;
}

my $error = $image->Read('../images/og_talk.png');
$image->Annotate(text=>Wrap('Javi Moreno',$image,600).
                 x=>270,y=>30);
$image->Set(weight    => 'Bold',);
$image->Annotate(text=> Wrap("<mm mmm mmm mmm mmm m m m m m m m m m m m m m m m m m m m m m m m m m m m m m El titulo de la cerrade xerrada mes llarg kfjldfjadsk d fkldf dksautor de la xerrrada>",$image,650),
                 x=>270,y=>66);
                 
$image->Draw(primitive=>'rectangle',
             pointsize=>1,
             stroke=>'red',
             fill=>'none',
             points=>'0,85,240,305',
             );
$image->Draw(primitive=>'line',
             strokewidth=>3, 
             stroke=>'white',
             fill=>'none',
             points=>'300,230,930,230',
             );
$image->Draw(primitive=>'line',
             strokewidth=>3, 
             stroke=>'white',
             fill=>'none',
             points=>'300,410,930,410',
             );
$image->Draw(primitive=>'line',
             strokewidth=>1, 
             stroke=>'red',
             fill=>'none',
             points=>'270,0,270,462',
             );
warn $error;
$image->Write('test.png');
 $error = $image->Display;
 undef $image;
 warn $error;

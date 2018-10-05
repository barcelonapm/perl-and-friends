#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use AnyEvent;
use AnyEvent::Loop;
use AnyEvent::Filesys::Notify;
use File::Basename;
use Template;
use YAML::Tiny qw/LoadFile/;
use Image::Magick;

my $current_dir = dirname(__FILE__);
my $template_dir = "$current_dir/../templates";
my $root_dir = "$current_dir/../..";

my $watch = $ARGV[0] eq '--watch' || $ARGV[0] eq '-w';

sub main {
    build_templates();

    if ($watch) {
        say "Watching changes to $root_dir";

        my $notifier = AnyEvent::Filesys::Notify->new(
            dirs => [ $root_dir ],
            filter   => sub { shift !~ /(\.html|~)$/ },
            cb => \&build_templates,
        );

        AnyEvent::Loop::run;
    }
}

sub build_templates {
    my $config = LoadFile("$current_dir/../config.yml")
        || die 'Problem loading config';

    $config->{schedule} = build_schedule($config);

    say "Building templates:";

    build_template('index.tt', $config, 'index.html');

    for my $talk (@{$config->{talks} || []}) {
        next unless $talk->{slug};
        build_template(
            'talk.tt',
            { conference => $config->{conference}, talk => $talk },
            "/talks/$talk->{slug}.html"
        );
        build_talk_ogg($talk->{slug},$talk->{author},$talk->{name},);
    }

    say "Done!";
}

sub build_talk_ogg  {
# uses Image::Magick to create a talk card grafic
    my ($id,$author,$title,$twitterid) = @_;
    my $image = Image::Magick->new(size=>'960x462',pointsize=>30,stroke=>'white',fill=>'white',);
    my $Wrap = sub {
    # This anonimous routine uses the current Image::Magick setings
    # to format an string in with a maximun len in pixels
    #
        my ($text, $img, $maxwidth) = @_;
    
        # figure out the width of every character in the string
        #
        my %widths = map(($_ => ($img->QueryFontMetrics(text=>$_))[4]),
            keys %{{map(($_ => 1), split //, $text)}});
        my ($pos,@newtext) = (0,);
        for (split //, $text) {
            # check to see if we're about to go out of bounds
            if ($widths{$_} + $pos > $maxwidth) {
                $pos = 0;
                my @word;
                # if we aren't already at the end of the word,
                #  loop until we hit the beginning
                if (       $newtext[-1] ne " "
                        && $newtext[-1] ne "-"
                        && $newtext[-1] ne "\n") {
                    unshift @word, pop @newtext
                        while (   @newtext && $newtext[-1] ne " "
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
    };

    $image->Read("$root_dir/images/og_talk.png"); 
    $image->Annotate( text=>$Wrap->($author,$image,650), #talk author,
                      x=>270,y=>30);
    $image->Set( weight => 'Bold',); #prepare for title
    $image->Annotate( text=> $Wrap->($title,$image,650),
                      x=>270,y=>66);
                 
    $image->Draw( primitive   => 'line',
                  strokewidth => 3, 
                  stroke      => 'white',
                  fill        => 'none',
                  points      => '300,230,930,230',);
    $image->Draw( primitive   => 'line',
                  strokewidth => 3, 
                  stroke      => 'white',
                  fill        => 'none',
                  points      => '300,410,930,410',);
    mkdir("$root_dir/images/talks/") unless -e "$root_dir/images/talks/";
    $image->Write("$root_dir/images/talks/$id.png");
    undef $image;
}

sub build_template {
    my ($template_file, $vars, $output_file) = @_;

    say "  - $output_file";

    my $template = Template->new({
        ABSOLUTE => 1,
        ENCODING => 'utf8',
    });

    $template->process(
        "$template_dir/$template_file",
        $vars,
        "$root_dir/$output_file",
        { binmode => ':utf8' },
    ) || die $template->error(), "\n";;
}

#
# Schedule data structure designed to be easy to print as an HTML table.
# It is a hash wich keys are times in a form of 'HH:MM'. There is a key for
# each 10 minutes interval.
#
# Both Events and Talks can expand vertically into multiple intervals. Their
# duration explicits how much down can they go.
#
# Events span for all the schedule rows, while talks must have a room and,
# therefore, can only expand vertically and not horizontally.
#
# An interval can't have 'event' and 'talks'.
#
# Each interval has a boolean 'label' that indicates if the time should be
# printed in the schedule. This will be true at every interval where an event
# or talk starts or finishes.
#
# Shape:
# {
#   label: Boolean,
#   event: {
#       name: String,
#       duration: Int,
#   },
#   talks: {
#       $room_index_1: {
#           author: String (Optional),
#           name: String,
#           slug String (Optional),
#           duration: Int,
#           accepted: Boolean,
#       },
#       // Talk expands vertically multiple intervals
#       $room_index_2: {
#           skip: true,
#       }
#   }
# }
#
# This is not intended to design schedules, only to print them. It will be
# easier for you if you first use a Spreadsheet to design the schedule and
# test all options and variations.
#
# The whole thing is a bit of a hack and edge cases are not handled. Printing
# arbitrary schedules in HTML tables is not easy and this is only designed
# to simplify our amateur work process.
#
# Just try not to overlap things and pray for the best :p
#
sub build_schedule {
    my $config = shift;

    my $schedule = {};

    for my $talk (@{$config->{talks} || []}) {
        next unless $talk->{accepted} && $talk->{time};

        my $start_time = $talk->{time};
        my $end_time = sum_minutes_to_time($talk->{duration}, $start_time);
        my $room = $talk->{room};

        $schedule->{$start_time}{label} = 1;
        $schedule->{$start_time}{talks}{$room} = $talk;
        $schedule->{$end_time}{label} = 1;

        for my $time (get_times_between($start_time, $end_time)) {
            $schedule->{$time}{talks}{$room}{skip} = 1;
        }
    };

    for my $event (@{$config->{events} || []}) {
        next unless $event->{time};

        my $start_time = $event->{time};
        my $end_time = sum_minutes_to_time($event->{duration}, $start_time);

        $schedule->{$start_time}{label} = 1;
        $schedule->{$start_time}{event} = $event;
        $schedule->{$end_time}{label} = 1;
    };

    # Ensure we have an entry every 10 minutes
    my @sorted_times = sort keys %$schedule;
    return unless @sorted_times;

    for my $time (get_times_between($sorted_times[0], $sorted_times[-1])) {
        $schedule->{$time}{label} ||= 0;
    }

    return $schedule;
}

sub sum_minutes_to_time {
    my ($minutes, $time) = @_;
    my ($time_hour, $time_minutes) = split(':', $time);

    my $added_minutes = ($time_minutes + $minutes) % 60;
    my $added_hour = $time_hour + int(($time_minutes + $minutes) / 60);

    return sprintf('%02d:%02d', $added_hour, $added_minutes);
}

sub get_times_between {
    my ($from, $to) = @_;

    my @interval;;
    my $current = $from;

    do {
        $current = sum_minutes_to_time(10, $current);
        push @interval, $current
    } while ($current ne $to);

    return @interval;
}

main();

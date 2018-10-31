Barcelona Perl & Friends
========================

The event formerly known as _Barcelona Perl Workshop_ mutated in
2017 to what's currently a more accurate description. Even though
the _Perl Workshop_ name was used traditionally for such events,
only people inside the Perl community understood that it wasn't
actually a workshop but a smaller conference in most cases.

The [Barcelona Perl Mongers](http://barcelona.pm) have long
embraced all sorts of people from other communities in their
events, thus making the new name a more appropiate match to
their usual attendees.

List of Events
--------------

The upcoming event is
[Barcelona Perl & Friends 2018](http://friends.barcelona.pm/2018).
There's also a list of [past events](http://barcelona.pm/#events).

How to Build the Current Website
--------------------------------

For docker fans:

```
cd 2018/_src
with_docker=please ./build
```

Without docker:

```
cd 2018/_src
sudo apt install build-essential cpanminus libimage-magick-perl
./build
```

When you're happy with the results, just commit and push them to
master or make a pull request for others to review.

Copyright & License
-------------------

Copyright © 2017-2018 Barcelona Perl Mongers http://barcelona.pm/

```
This program is free software; you can redistribute it and/or modify
it under the terms of the "Artistic License" which comes with Perl.
See LICENSE for details.
```

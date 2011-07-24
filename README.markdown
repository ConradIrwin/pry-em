# Introduction

`pry-em` is a plugin for the Ruby shell [pry](http://pry.github.com) which allows you to poke around with objects in [EventMachine](http://rubyeventmachine.com). It's designed to make playing with async stuff as easy as pry!

## How to use it?

As with all pry plugins, you can just:

    gem install pry-em

Then, any time you want to run a command that returns a deferrable, prefix it by `em:`. For example:

    pry(main)> em: EM::HttpRequest.new("http://example.com/").get

This does two things. Firstly, before running your command, it ensures that EventMachine is running. And Secondly, it sits and waits for your deferrable to succeed or fail before returning the result to you in `_`

    pry(main)> em: EM::HttpRequest.new("http://example.com/").get
    callback => #<EventMachine::HttpClient:0x25b36f8
                  @bytes_remaining=0,
                  …

    pry(main)> em: EM::HttpRequest.new("http://examplefail/").get
    errback => #<EventMachine::HttpClient:0x25b36f8
                  @bytes_remaining=0,
                  @error="unable to resolve server address",
                  …

If your deferrable takes a loong time to succeed or fail (where a long time is "more than 3 seconds" by default), a timeout error will be raised. You can configure the length of the timeout by putting a number of seconds into the prefix:

    pry(main)> em 10: EM::HttpRequest.new("https://slow.domain.example.com/").get
    RuntimeError: Timeout after 10 seconds
    from /0/ruby/pry-em/lib/pry-em.rb:71:in `wait_for_deferrable'

## How does it work? (aka. it's broken, why?!)

The basic magic is to boot the EM reactor into a different thread from that which is running the Pry shell. When you want to run something that requires the reactor, we send it across to the eventmachine thread, and then enter a simple "sleep until done" loop.

Unfortunately it's possibly (and in fact quite easy) to boot Pry into a thread which is already running the EM reactor. In this case, if we were to enter the "sleep until done" loop, we'd never make any progress, as the stuff that needed doing would be waiting for us to stop sleeping. If `pry-em` notices that this has happened, it will raise an Exception with a friendly message.

## Metafoo

`pry-em` is licensed under the MIT license, see LICENSE.MIT for details. Bug-reports, feature-requests and patches are most welcome.

I'm indebted to @samstokes for some of the ideas behind `pry-em` (though the faults in the implementation are all mine).

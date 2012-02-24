EmCommands = Pry::CommandSet.new do

  create_command /\s*em\s*([0-9\.]*)\s*:(.*)/ do

    description "Run code in eventmachine and wait for any Deferrable results."
    options(
      :keep_retval  => true,
      :interpolate  => false,
      :listing      => "em",
      :requires_gem => 'eventmachine'
    )

    banner <<-BANNER
      The em: command runs your code in an event machine context.

      If your code returns a deferrable, it wil wait for that deferrable to succeed
      or fail before returning you to Pry.

      By default the em: command will wait forever for your deferrable to return
      a result, if you'd like to wait for a shorter length of time, you can add
      a timeout (in seconds) before the colon in em:.

      e.g.
        pry(main)> em 3: EM::HttpRequest.new("http://www.google.com").get
        RuntimeError: Timeout after 3.0 seconds

    BANNER

    def process(timeout, source)
      # We store the retval and the em-state in globals so that we can catch exceptions
      # raised in the event loop and pass them back pretending to the user that the
      # exception was caused by their currently executing command.
      #
      # We don't want to keep turning the reactor on and off, as that would limit some
      # of the things the user might want to do.
      @@retval, @@em_state = [nil, :waiting]

      # Boot EM before eval'ing the source as it's likely to depend on the reactor.
      run_em_if_necessary!

      # This can happen for example if you do:
      #  em: EM::HttpRequest.new("http://www.google.com/").get.callback{ binding.pry }
      # There ought to be a solution, but it will involve shunting either Pry or EM
      # onto a new thread.
      if EM.reactor_thread == Thread.current
        raise "Could not wait for deferrable, you're in the EM thread!
                If you don't know what to do, try `cd ..`, or just hit ctrl-C until it dies."
      end

      deferrable = target.eval(source)

      # TODO: Allow the user to configure the default timeout
      timeout = timeout == "" ? nil : Float(timeout)

      wait_for_deferrable(deferrable, timeout) unless deferrable.nil?
    end

    # Boot a new EventMachine reactor into another thread.
    # This allows us to continue to interact with the user on the front-end thread,
    # while they run event-machine commands in the background.
    def run_em_if_necessary!
      require 'eventmachine' unless defined?(EM)
      unless EM.reactor_running?
        Thread.new do
          EM.error_handler{ |e| handle_unexpected_error(e) }
          begin
            EM.run
          rescue Pry::RescuableException => e
            handle_unexpected_error(e)
          end
        end
      end
      sleep 0.01 until EM.reactor_running?
    end

    # If we were the ones to start the EM reactor, we want to catch
    # any exceptions that are raised therein and tell the user about
    # them.
    #
    # If they are still waiting for an async event, assume that this
    # was in relation to that.
    #
    # If not, just print out the error and hope they don't get too
    # confused.
    def handle_unexpected_error(e)
      if waiting?
        @@em_state = :em_error
        @@retval = e
      else
        output.puts "Unexpected exception from EventMachine reactor"
        _pry_.last_exception = e
        _pry_.show_result(e)
      end
    rescue => e
      puts e
    end

    # Run a deferrable on an EM reactor in a different thread,
    # sleep until it has finished, and then return the result.
    #
    # The result is defined to be as useful to an interactive shell user as possible:
    #
    # If the deferrable succeeds or fails with one argument, that one argument is
    # returned; though if it succeeds or fails with many arguments, an array is returned.
    #
    def wait_for_deferrable(deferrable, timeout)

      if timeout
        EM::Timer.new(timeout) { @@em_state = :timeout if waiting? }
      end

      [:callback, :errback].each do |method|
        begin
          deferrable.__send__ method do |*result|
            @@em_state = method
            @@retval = result.size > 1 ? result : result.first
          end
        rescue NoMethodError
          @@retval = deferrable
          @@em_state = :callback
          break
        end
      end

      sleep 0.01 until @@em_state != :waiting

      raise "Timeout after #{timeout} seconds" if @@em_state == :timeout

      # Use Pry's (admittedly nascent) handling for exceptions where possible.
      raise @@retval if @@em_state != :callback && Exception === @@retval

      # TODO: This doesn't interact well with the pager.
      output.print "#{@@em_state} " if @@em_state != :callback

      @@retval

    # If the main thread is interrupted we must ensure that the @@em_state
    # is no-longer :waiting so that handle_unexpected_error can do the
    # right thing.
    ensure
      @@em_state = :interrupted if waiting?
    end

    def waiting?
      @@em_state == :waiting
    end
  end
end
Pry.config.commands.import EmCommands

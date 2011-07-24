EmCommands = Pry::CommandSet.new do

  EM_DESCRIPTION = "Wait for a deferrable to succeed or fail, a timeout can be specified before the colon."
  EM_CONFIG = {
    :keep_retval  => true,
    :interpolate  => false,
    :listing      => "em[timeout=3]:",
    :requires_gem => 'eventmachine'
  }

  command /\s*em\s*([0-9\.]*)\s*:(.*)/, EM_DESCRIPTION, EM_CONFIG do |timeout, source|

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
    timeout = timeout == "" ? 3 : Float(timeout)

    wait_for_deferrable(deferrable, timeout) unless deferrable.nil?
  end

  helpers do
    # Boot a new EventMachine reactor into another thread.
    # This allows us to continue to interact with the user on the front-end thread,
    # while they run event-machine commands in the background.
    def run_em_if_necessary!
      require 'eventmachine' unless defined?(EM)
      Thread.new{ EM.run } unless EM.reactor_running?
      sleep 0.01 until EM.reactor_running?
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

      retval, finished = nil

      EM::Timer.new(timeout) { finished ||= :timeout }

      [:callback, :errback].each do |method|
        begin
          deferrable.__send__ method do |*result|
            finished = method
            retval = result.size > 1 ? result : result.first
          end
        rescue NoMethodError
          output.warn "WARNING: is not deferrable? #{deferrable}"
          break
        end
      end

      sleep 0.01 until finished

      raise "Timeout after #{timeout} seconds" if finished == :timeout

      # TODO: This doesn't interact well with the pager.
      output.print "#{finished} " #=> 
      retval
    end
  end
end
Pry.config.commands.import EmCommands

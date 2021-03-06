module RedisFailover
  # Watches a specific redis node for its availability.
  class NodeWatcher
    include Util

    WATCHER_SLEEP_TIME = 2

    def initialize(manager, node, max_failures)
      @manager = manager
      @node = node
      @max_failures = max_failures
      @monitor_thread = nil
      @done = false
    end

    def watch
      @monitor_thread = Thread.new { monitor_node }
      self
    end

    def shutdown
      @done = true
      @node.wakeup
      @monitor_thread.join if @monitor_thread
    rescue
      # best effort
    end

    private

    def monitor_node
      failures = 0

      loop do
        begin
          return if @done
          sleep(WATCHER_SLEEP_TIME)
          @node.ping
          failures = 0

          if @node.syncing_with_master?
            notify(:syncing)
          else
            notify(:available)
            @node.wait
          end
        rescue NodeUnavailableError
          failures += 1
          if failures >= @max_failures
            notify(:unavailable)
            failures = 0
          end
        end
      end
    end

    def notify(state)
      @manager.notify_state_change(@node, state)
    end
  end
end

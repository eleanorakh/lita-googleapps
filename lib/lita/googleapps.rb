require "lita"

module Lita
  class Googleapps < Handler
    TIMER_INTERVAL = 60

    config :service_account_email
    config :service_account_key
    config :service_account_secret
    config :domains
    config :user_email
    config :channel_name
    config :max_weeks_without_login

    on :loaded, :start_timers

    def start_timers(payload)
      start_max_weeks_without_login_timer
      start_admin_activities_timer
    end

    private

    def start_admin_activities_timer
      every_with_logged_errors(TIMER_INTERVAL) do |timer|
        sliding_window.advance(duration_minutes: 30, buffer_minutes: 30) do |window_start, window_end|
          list_activities(window_start, window_end)
        end
      end
    end

    def start_max_weeks_without_login_timer
      return if config.max_weeks_without_login.to_i < 1

      every_with_logged_errors(TIMER_INTERVAL) do |timer|
        persistent_every("max-weeks-with-login", weeks_in_seconds(1)) do
          msg = MaxWeeksWithoutLoginMessage.new(gateway, config.max_weeks_without_login).to_msg
          robot.send_message(target, msg) if msg
        end
      end
    end

    def weeks_in_seconds(weeks)
      60 * 60 * 24 * 7 * weeks.to_i
    end

    def every_with_logged_errors(interval, &block)
      logged_errors do
        every(interval, &block)
      end
    end

    def logged_errors(&block)
      yield
    rescue Exception => e
      puts "Error in timer loop: #{e.inspect}"
    end

    def persistent_every(name, seconds, &block)
      PersistentEvery.new(name, redis).execute_after(seconds, &block)
    end

    def sliding_window
      @sliding_window ||= SlidingWindow.new("last_activity_list_at", redis)
    end

    def list_activities(window_start, window_end)
      gateway.admin_activities(window_start, window_end).sort_by(&:time).each do |activity|
        robot.send_message(target, activity.to_msg)
      end
    end

    def target
      Source.new(room: Lita::Room.find_by_name(config.channel_name) || "general")
    end

    def gateway
      @gateway ||= Lita::GoogleAppsGateway.new(
        service_account_email: config.service_account_email,
        service_account_key: config.service_account_key,
        service_account_secret: config.service_account_secret,
        domains: config.domains,
        acting_as_email: config.user_email
      )
    end

    Lita.register_handler(self)
  end
end

module Lita
  class GoogleActivity
    attr_reader :time, :actor, :ip, :name, :params

    def self.from_api(item)
      item.events.map { |event|
        GoogleActivity.new(
          time: item.id.time,
          actor: item.actor.email,
          ip: item.ip_address,
          name: event.name,
          params: event.parameters.inject({}) { |accum, param|
            accum[param.name] = param.value
            accum
          }
        )
      }
    end

    def initialize(time:, actor:, ip:, name:, params:)
      @time = time
      @actor = actor
      @ip = ip
      @name = name
      @params = params
    end

    def to_s
      @actor
    end

    def to_msg
      "#{@time.iso8601} #{@actor} #{@name}: #{@params.inspect}"
    end
  end
end

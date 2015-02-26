module Agents
  class WebsocketAgent < Agent

    cannot_receive_events!

    description <<-MD
      TODO
    MD

    event_description <<-MD
      TODO
    MD

    cannot_be_scheduled!

    def validate_options
      #unless options['filters'].present? &&
      #       options['expected_update_period_in_days'].present? &&
      #       options['generate'].present?
      #  errors.add(:base, "expected_update_period_in_days, generate, and filters are required fields")
      #end
      true
    end

    def working?
      true # TODO check if websocket is connected
    end

    def default_options
      {
        'filters' => %w[keyword1 keyword2],
        'expected_update_period_in_days' => "2",
        'generate' => "events"
      }
    end

    def receive_web_request(params, method, format)
      secret = params.delete('secret')
      return ["Please use POST requests only", 401] unless method == "post"
      return ["Not Authorized", 401] unless secret == guid
      create_event(:payload => params)

      ['Event Created', 201]
    end

    #def check
    #  if interpolated['generate'] == "counts" && memory['filter_counts'] && memory['filter_counts'].length > 0
    #    memory['filter_counts'].each do |filter, count|
    #      create_event :payload => { 'filter' => filter, 'count' => count, 'time' => Time.now.to_i }
    #    end
    #  end
    #  memory['filter_counts'] = {}
    #end

    protected

  end
end

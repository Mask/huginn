require 'cgi'
require 'json'
require 'em-http-request'
require 'pp'

class WebsocketManager


  def initialize
    @running = true
    @websockets = {}
  end

  def stop
    @running = false
  end

  def connect!(agent)

    # uri = agent.websocket_uri
    uri = 'wss://echo.websocket.org/?encoding=text'
    ws = WebSocket::EventMachine::Client.connect(:uri => uri)
    web_request = Rails.application.routes.url_helpers.url_for(
      controller: :web_requests,
      host: ENV['DOMAIN'],
      action: :handle_request,
      user_id: agent.user_id,
      secret: agent.guid,
      agent_id: agent.id
    )
    puts "#{self.class.to_s} events from #{uri} will be forwarded to #{web_request}"

    @websockets[agent.id] = {
      ws: ws,
      uri: uri,
      web_request: web_request
    }

    ws.onerror do |reason|
      STDERR.puts " --> websocket error '#{reason}' with #{agent.uri} <--"
      @websockets.delete(agent.id)
    end

    ws.onopen do
      puts "Connected to #{uri}"
      ws.send JSON::generate({ :foo => 'bar' })
    end

    ws.onmessage do |msg, type|
      puts "Received message: #{msg}"
      begin
        msg = JSON.parse(msg)
      rescue
      end
      http = EventMachine::HttpRequest.new(web_request).post body: { message: msg }

      http.errback { p 'Uh oh' }
      http.callback {
        p http.response_header.status
        p http.response_header
        p http.response
      }
    end

    ws.onclose do |code, reason|
      puts "Disconnected from #{uri} with status code: #{code} '#{reason}'"
      @websockets.delete(agent.id)
    end
  end

  def run
    if Agents::WebsocketAgent.dependencies_missing?
      STDERR.puts Agents::WebsocketAgent.websocket_dependencies_missing
      STDERR.flush
      return
    end


    while @running
      begin

        EventMachine::run do
          EventMachine.add_periodic_timer(1) {
            EventMachine::stop_event_loop if !@running
          }

          EventMachine.add_periodic_timer(10) {
            agents = Agents::WebsocketAgent.active.all
            connect_idle_agents agents
            disconnect_orphan_websockets agents
          }
        end
        connect_idle_agents Agents::WebsocketAgent.active.all
      rescue SignalException, SystemExit
        @running = false
        EventMachine::stop_event_loop if EventMachine.reactor_running?
      rescue StandardError => e
        STDERR.puts "\nException #{e.message}:\n#{e.backtrace.join("\n")}\n\n"
        STDERR.puts "Waiting for a couple of minutes..."
        sleep 120
      end
    end
  end

private

  def connect_idle_agents agents
    # look for agents which are not yet in our connection map
    idle = agents.select { |agent| !@websockets.keys.include?(agent.id) }
    if idle.length > 0
      puts "#{self.class.to_s} found #{idle.length} active but unconnected agents"
      idle.each do |agent|
        connect! agent
      end
    end
  end

  def disconnect_orphan_websockets agents
    orphaned = @websockets.select { |a_id,conn| !agents.any? { |a| a.id == a_id}  }
    orphaned.each do |a_id, conn|
      puts "#{select.class.to_s} closing #{conn.inspect}"
      conn.close
    end
  end
end

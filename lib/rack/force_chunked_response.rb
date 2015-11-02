module Rack
  class ForceChunkedResponse
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)
      if headers.has_key?('Content-Length')
        headers.delete('Content-Length')
      end
      [status, headers, response]
    end
  end
end

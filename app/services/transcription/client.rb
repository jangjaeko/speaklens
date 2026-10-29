require "net/http"

module Transcription
  # Sends audio to Deepgram's pre-recorded API and returns provider-agnostic results.
  # See docs/decisions/001-stt-provider.md for why these options were chosen.
  class Client
    ENDPOINT = URI("https://api.deepgram.com/v1/listen?model=nova-3&diarize=true&utterances=true&smart_format=true")

    Error = Class.new(StandardError)
    RetryableError = Class.new(Error) # Network trouble, rate limits, Deepgram outages
    PermanentError = Class.new(Error) # Bad audio, bad key: retrying won't help

    Result = Data.define(:request_id, :duration_seconds, :utterances)
    Utterance = Data.define(:speaker, :text, :start_ms, :end_ms)

    def self.parse(json)
      Result.new(
        request_id: json.dig("metadata", "request_id"),
        duration_seconds: json.dig("metadata", "duration"),
        utterances: json.dig("results", "utterances").map do |utterance|
          Utterance.new(
            speaker: utterance["speaker"],
            text: utterance["transcript"],
            start_ms: (utterance["start"] * 1000).round,
            end_ms: (utterance["end"] * 1000).round
          )
        end
      )
    end

    def initialize(api_key: ENV["DEEPGRAM_API_KEY"].presence || Rails.application.credentials.dig(:deepgram, :api_key))
      @api_key = api_key
    end

    def transcribe(io, content_type:)
      raise PermanentError, "Deepgram API key is not configured" if @api_key.blank?

      response = post(io, content_type)
      check_status!(response.code.to_i, response.body)
      self.class.parse(JSON.parse(response.body))
    rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError => error
      raise RetryableError, "Deepgram request failed: #{error.class}"
    end

    private
      def post(io, content_type)
        request = Net::HTTP::Post.new(ENDPOINT)
        request["Authorization"] = "Token #{@api_key}"
        request["Content-Type"] = content_type
        request["Content-Length"] = io.size.to_s
        request.body_stream = io

        Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 10, read_timeout: 300) do |http|
          http.request(request)
        end
      end

      def check_status!(status, body)
        return if (200..299).cover?(status)

        # Deepgram's error body describes the problem (e.g. unsupported audio); it never echoes the key.
        message = "Deepgram returned HTTP #{status}: #{body.to_s.truncate(300)}"
        raise RetryableError, message if status == 408 || status == 429 || status >= 500
        raise PermanentError, message
      end
  end
end

require "test_helper"

class Transcription::ClientTest < ActiveSupport::TestCase
  # Replaces the HTTP call so tests never reach Deepgram.
  class FakeHttpClient < Transcription::Client
    def initialize(code:, body: "", raises: nil)
      super(api_key: "test-key")
      @response = Struct.new(:code, :body).new(code.to_s, body)
      @raises = raises
    end

    private
      def post(_io, _content_type)
        raise @raises if @raises
        @response
      end
  end

  setup { @audio = StringIO.new("fake audio") }

  test "parses a real Deepgram response into utterances" do
    body = file_fixture("deepgram/single_speaker.json").read
    result = FakeHttpClient.new(code: 200, body: body).transcribe(@audio, content_type: "audio/webm")

    assert_equal "01a189da-16f7-7e13-adc9-f004eb3c3a17", result.request_id
    assert_in_delta 60.42, result.duration_seconds
    assert_equal 8, result.utterances.size

    first = result.utterances.first
    assert_equal 0, first.speaker
    assert_equal "So I've been working as a software developer for about three years.", first.text
    assert_equal 1440, first.start_ms
    assert_equal 8800, first.end_ms
  end

  test "a response with no speech has no utterances" do
    body = { metadata: { request_id: "abc", duration: 3.0 }, results: { channels: [ { alternatives: [ { transcript: "" } ] } ] } }.to_json
    result = FakeHttpClient.new(code: 200, body: body).transcribe(@audio, content_type: "audio/webm")

    assert_empty result.utterances
  end

  test "rate limits and server errors are retryable" do
    [ 429, 500, 503 ].each do |code|
      assert_raises(Transcription::Client::RetryableError) do
        FakeHttpClient.new(code: code).transcribe(@audio, content_type: "audio/webm")
      end
    end
  end

  test "bad requests are permanent" do
    error = assert_raises(Transcription::Client::PermanentError) do
      FakeHttpClient.new(code: 400, body: '{"err_msg":"corrupt or unsupported data"}').transcribe(@audio, content_type: "audio/webm")
    end
    assert_match "corrupt or unsupported data", error.message
  end

  test "network timeouts are retryable" do
    assert_raises(Transcription::Client::RetryableError) do
      FakeHttpClient.new(code: 200, raises: Net::ReadTimeout).transcribe(@audio, content_type: "audio/webm")
    end
  end

  test "a missing API key is permanent" do
    assert_raises(Transcription::Client::PermanentError) do
      Transcription::Client.new(api_key: nil).transcribe(@audio, content_type: "audio/webm")
    end
  end
end

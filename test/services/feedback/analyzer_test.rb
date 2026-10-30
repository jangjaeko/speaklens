require "test_helper"

class Feedback::AnalyzerTest < ActiveSupport::TestCase
  # Stands in for Anthropic::Client: client.beta.messages.create(...) returns a canned response.
  class FakeClient
    Response = Struct.new(:stop_reason, :content)
    TextBlock = Struct.new(:type, :text)

    attr_reader :params

    def initialize(text: nil, stop_reason: :end_turn, raises: nil)
      @text, @stop_reason, @raises = text, stop_reason, raises
    end

    def beta = self
    def messages = self

    def create(**params)
      @params = params
      raise @raises if @raises
      Response.new(@stop_reason, [ TextBlock.new(:text, @text) ])
    end
  end

  setup do
    @sentences = [ { speaker: "other", text: "Tell me about yourself." }, { speaker: "me", text: "I'm, like, a developer." } ]
    @fixture = file_fixture("claude/analysis.json").read
  end

  def analyze_with(client)
    Feedback::Analyzer.new(client: client).analyze(@sentences)
  end

  def api_error(klass, status)
    klass.new(url: URI("https://api.anthropic.com/v1/messages"), status: status, headers: {}, body: nil, request: nil, response: nil)
  end

  test "parses a real Claude response" do
    result = analyze_with FakeClient.new(text: @fixture)

    assert_match "clear, logical introduction", result.summary
    assert_equal 7, result.corrections.size
    assert_equal "that help users to track", result.corrections.first["original"]
    assert_includes result.habit_occurrences.map { _1["phrase"] }, "you know"
  end

  test "sends numbered sentences with speakers, a JSON schema, and fallbacks" do
    client = FakeClient.new(text: @fixture)
    analyze_with client

    assert_equal "claude-opus-5-5", client.params[:model]
    assert_equal "Transcript:\n0 [other] Tell me about yourself.\n1 [me] I'm, like, a developer.", client.params[:messages].first[:content]
    assert_equal :json_schema, client.params.dig(:output_config, :format_, :type)
    assert_equal :default, client.params[:fallbacks]
  end

  test "a refusal is permanent" do
    assert_raises(Feedback::Analyzer::PermanentError) { analyze_with FakeClient.new(text: "", stop_reason: :refusal) }
  end

  test "a malformed response is retryable" do
    assert_raises(Feedback::Analyzer::RetryableError) { analyze_with FakeClient.new(text: '{"summary": "hi"}') }
  end

  test "rate limits, outages and network errors are retryable" do
    [
      api_error(Anthropic::Errors::RateLimitError, 429),
      api_error(Anthropic::Errors::InternalServerError, 529),
      Anthropic::Errors::APIConnectionError.new(url: URI("https://api.anthropic.com"))
    ].each do |error|
      assert_raises(Feedback::Analyzer::RetryableError) { analyze_with FakeClient.new(raises: error) }
    end
  end

  test "other API errors are permanent" do
    assert_raises(Feedback::Analyzer::PermanentError) do
      analyze_with FakeClient.new(raises: api_error(Anthropic::Errors::AuthenticationError, 401))
    end
  end
end

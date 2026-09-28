# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Captcha::Result do
  it 'serialises a solved result with its token' do
    result = described_class.solved(:recaptcha, token: 'abc', attempts: 2, transcriptions: ['hello world'])

    expect(result).to be_solved
    expect(result.to_h).to include(solved: true, type: 'recaptcha', status: 'solved', attempts: 2,
                                   token: 'abc', token_length: 3, transcriptions: ['hello world'])
  end

  it 'serialises an unsolved result without a token' do
    result = described_class.unsolved(:turnstile, :blocked, 'nope', attempts: 1)

    expect(result).not_to be_solved
    expect(result.to_h).to eq(solved: false, type: 'turnstile', status: 'blocked', attempts: 1, message: 'nope')
  end
end

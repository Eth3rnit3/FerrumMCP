# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Captcha::Detector do
  describe '.types_for_urls' do
    it 'recognises reCAPTCHA anchors on google.com and recaptcha.net, including enterprise' do
      urls = ['https://www.google.com/recaptcha/api2/anchor?ar=1&k=key&hl=fr',
              'https://www.recaptcha.net/recaptcha/enterprise/anchor?k=key']
      urls.each { |url| expect(described_class.types_for_urls([url])).to eq([:recaptcha]) }
    end

    it 'ignores the reCAPTCHA challenge frame on its own' do
      expect(described_class.types_for_urls(['https://www.google.com/recaptcha/api2/bframe?k=key'])).to be_empty
    end

    it 'recognises the hCaptcha checkbox frame but not the challenge frame' do
      checkbox = 'https://newassets.hcaptcha.com/captcha/v1/abc/static/hcaptcha.html#frame=checkbox&id=0'
      challenge = 'https://newassets.hcaptcha.com/captcha/v1/abc/static/hcaptcha.html#frame=challenge&id=0'

      expect(described_class.types_for_urls([checkbox])).to eq([:hcaptcha])
      expect(described_class.types_for_urls([challenge])).to be_empty
    end

    it 'recognises Cloudflare Turnstile frames' do
      url = 'https://challenges.cloudflare.com/cdn-cgi/challenge-platform/h/b/turnstile/if/ov2/av0/rcv/abc/0x4AAA/light/normal'
      expect(described_class.types_for_urls([url])).to eq([:turnstile])
    end

    it 'does not match look-alike URLs on other hosts' do
      urls = ['https://evil.example/www.google.com/recaptcha/api2/anchor',
              'https://example.com/?next=https://challenges.cloudflare.com/']
      expect(described_class.types_for_urls(urls)).to be_empty
    end

    it 'reports every type present, in a stable order' do
      urls = ['https://challenges.cloudflare.com/turnstile', 'https://www.google.com/recaptcha/api2/anchor?k=1']
      expect(described_class.types_for_urls(urls)).to eq(%i[recaptcha turnstile])
    end
  end

  describe '.solver_class' do
    it 'maps each type to its solver' do
      expect(described_class.solver_class(:recaptcha)).to eq(FerrumMCP::Captcha::RecaptchaSolver)
      expect(described_class.solver_class('hcaptcha')).to eq(FerrumMCP::Captcha::HcaptchaSolver)
      expect(described_class.solver_class(:turnstile)).to eq(FerrumMCP::Captcha::TurnstileSolver)
    end
  end
end

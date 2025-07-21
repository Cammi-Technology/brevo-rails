require 'spec_helper'


RSpec.describe BrevoRails::Mail do
  let(:text_part) do
    Mail::Part.new do
      body 'This is plain text'
    end
  end

  let(:html_part) do
    Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body '<h1>This is HTML</h1>'
    end
  end

  let(:message) do
    Mail.new do
      from    'Tester <test@example.com>'
      to      'you@example.com, her@example.com'
      subject 'This is a test email'
      headers 'X-Custom-Header' => 'Custom Value'
    end
  end


  before do
    message.text_part = text_part
    message.html_part = html_part
  end

  describe '.from_message' do
    subject { BrevoRails::Mail.from_message(message) }

    it 'returns a new instance of Brevo::SendSmtpEmail' do
      expect(subject).to be_a(Brevo::SendSmtpEmail)
    end

    it 'sets the mail subject' do
      expect(subject.subject).to eq('This is a test email')
    end

    it 'sets the mail sender' do
      expect(subject.sender).to be_a(Brevo::SendSmtpEmailSender)
      expect(subject.sender.email).to eq('test@example.com')
      expect(subject.sender.name).to eq('Tester')
    end

    it 'sets the mail to' do
      expect(subject.to).to be_a(Array)
      expect(subject.to.first).to be_a(Brevo::SendSmtpEmailTo)
      expect(subject.to.map(&:email)).to include('you@example.com')
      expect(subject.to.map(&:email)).to include('her@example.com')
    end

    it 'sets the mail text content' do
      expect(subject.text_content).to eq('This is plain text')
      expect(subject.html_content).to eq('<h1>This is HTML</h1>')
    end

    it 'sets the mail headers' do
      custom_header = subject.headers.fetch('X-Custom-Header')
      expect(custom_header).to eq('Custom Value')
    end

    it 'does not set attachments' do
      expect(subject.attachment).to be_nil
    end

    context 'with attachments' do
      let(:message_with_attachments) do
        Mail.new do
          from    'Tester <test@example.com>'
          to      'you@example.com, her@example.com'
          subject 'This is a test email'
          attachments['test.png'] = File.read('spec/fixtures/test.png')
        end
      end

      subject { BrevoRails::Mail.from_message(message_with_attachments) }

      it 'sets attachments' do
        expect(subject.attachment).to be_a(Array)
        expect(subject.attachment.size).to eq(1)
        expect(subject.attachment.first.name).to eq('test.png')
      end
    end

    context 'with tags' do
      let(:message_with_tags) do
        Mail.new(from: 'Tester <test@example.com>',
                 to: 'you@example.com, her@example.com',
                 subject: 'This is a test email',
                 tags: ['tag1', 'tag2'])
      end

      subject { BrevoRails::Mail.from_message(message_with_tags) }

      it 'sets tags' do
        expect(subject.tags).to eq(['tag1', 'tag2'])
      end
    end

    context 'with template delivery_method_options' do
      let(:message) do
        Mail.new do
          from    'Tester <test@example.com>'
          to      'you@example.com'
          subject 'Should be ignored by Brevo'
        end
      end

      before do
        # Simulate ActionMailer injecting delivery_method_options
        def message.delivery_method_options
          {
            template_id: 12345,
            template_params: {
              first_name: 'Rachel',
              verification_link: 'https://cammi.app/confirm?token=abc'
            }
          }
        end

        message.text_part = Mail::Part.new { body 'Text fallback' }
        message.html_part = Mail::Part.new { content_type 'text/html'; body '<p>Hello</p>' }
      end

      subject(:smtp_payload) { described_class.from_message(message) }

      it 'sets the template ID' do
        expect(smtp_payload.template_id).to eq(12345)
      end

      it 'sets the template params' do
        expect(smtp_payload.params).to eq({
          'first_name' => 'Rachel',
          'verification_link' => 'https://cammi.app/confirm?token=abc'
        })
      end

      it 'omits htmlContent and textContent' do
        expect(smtp_payload.html_content).to be_nil
        expect(smtp_payload.text_content).to be_nil
      end
    end
  end

end

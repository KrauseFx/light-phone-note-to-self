require 'pry'
require 'excon'
require 'json'
require 'net/http'
require 'net/https'

class Run
  attr_accessor :bearer_token
  attr_accessor :device_tool_id

  def initialize(bearer_token:, device_tool_id:)
    self.bearer_token = bearer_token
    self.device_tool_id = device_tool_id
  end

  def run
    raise "Bearer token must include 'Bearer ' prefix" unless bearer_token.start_with?('Bearer ')
    
    all_notes = JSON.parse(Excon.get(
      'https://production.lightphonecloud.com/api/notes',
      headers: headers,
      query: {
        device_tool_id: device_tool_id
      }
    ).body).fetch("data")
    
    all_notes.each do |note|
      note_content = download_note_content_with_id(note.fetch("id"))
      if note_content.length > 0
        title = note.fetch("attributes").fetch("title")
        send_email(title: title, content: note_content)
      else
        puts "Note with id #{note.fetch('id')} has no content"
      end
    rescue => e
      puts "Error processing note with id #{note.fetch('id')}: #{e}"
    end
  end

  private
  def download_note_content_with_id(note_id)
    presigned_get_url = JSON.parse(Excon.get(
      "https://production.lightphonecloud.com/api/notes/#{note_id}/generate_presigned_get_url",
      headers: headers
    ).body).fetch("presigned_get_url")

    # For some reason, the below code wouldn't work with Excon, not worth investigating imo
    uri = URI(presigned_get_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri)
    res = http.request(req)
    return res.body
  end
  
  def send_email(title:, content:)
    binding.pry
    if title == "Untitled"
      title = content.split("\n").first
    end

    email_post = Excon.post(
      'https://api.sendgrid.com/v3/mail/send',
      headers: {
        'Authorization' => ENV.fetch('SENDGRID_BEARER_TOKEN'),
        'Content-Type' => 'application/json'
      },
      body: {
        from: {
          email: ENV.fetch('SENDGRID_FROM')
        },
        content: [
          {
            type: 'text/plain',
            value: content
          }
        ],
        personalizations: [
          {
            to: [
              {
                email: ENV.fetch('SENDGRID_TO')
              }
            ],
            subject: "[Major 🔑] #{title}"
          }
        ]
      }.to_json
    )

    binding.pry
    puts 'hi'
  end

  def headers
    return { 'Authorization' => bearer_token }
  end
end

if __FILE__ == $0
  Run.new(bearer_token: ENV.fetch('BEARER_TOKEN'), device_tool_id: ENV.fetch('DEVICE_TOOL_ID')).run
end

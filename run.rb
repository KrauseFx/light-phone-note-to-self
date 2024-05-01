require 'pry'
require 'fileutils'
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
      if notes_already_stored.include?(note.fetch("id"))
        puts "Note with id #{note.fetch('id')} has already been processed"
        next
      end

      note_content = download_note_content_with_id(note.fetch("id"))
      if note_content.length > 0
        title = note.fetch("attributes").fetch("title")
        updated_at = note.fetch("attributes").fetch("updated_at")
        if title == "Untitled" # this is the default title for notes on the Light Phone
          title = note_content.split("\n").first
        end
        puts "Processing note with id #{note.fetch('id')} and content #{title}..."
        store_note_locally(note.fetch("id"), title, note_content, updated_at)

        if ENV['SENDGRID_BEARER_TOKEN'].to_s.length > 0
          send_email(title: title, content: note_content)
        else
          puts "No SENDGRID_BEARER_TOKEN found, skipping email sending"
        end
        append_to_notes_already_stored(note.fetch("id"))
        puts "Successfully sent email for note with id #{note.fetch('id')}"
      else
        puts "Note with id #{note.fetch('id')} has no content"
      end
    # rescue => e
    #   puts "Error processing note with id #{note.fetch('id')}: #{e}"
    #   binding.pry
    end
  end

  private
  def store_note_locally(note_id, title, content, updated_at)
    FileUtils.mkdir_p("notes")
    file_safe_title = title.gsub(/[^0-9a-z ]/i, '').gsub(" ", "_")
    file_safe_updated_at = updated_at.gsub(":", "-")
    to_store = []
    to_store << title if title != content
    to_store << content
    to_store << updated_at
    File.open("notes/#{file_safe_updated_at}_#{file_safe_title}.txt", "w") do |f|
      f.puts(to_store.join("\n\n"))
    end
    puts("Stored note with id #{note_id} locally")
  end

  def notes_already_stored
    if File.exist?("notes_already_stored")
      return File.read("notes_already_stored").split("\n")
    end
    return []
  end

  def append_to_notes_already_stored(note_id)
    File.open("notes_already_stored", "a") do |f|
      f.puts(note_id)
    end
  end

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
    email_post = Excon.post(
      'https://api.sendgrid.com/v3/mail/send',
      headers: {
        'Authorization' => ENV.fetch('SENDGRID_BEARER_TOKEN'),
        'Content-Type' => 'application/json'
      },
      body: {
        from: { email: ENV.fetch('SENDGRID_FROM') },
        content: [
          {
            type: 'text/plain',
            value: content
          }
        ],
        personalizations: [
          {
            to: [{ email: ENV.fetch('SENDGRID_TO') } ],
            subject: "[Major 🔑] #{title}"
          }
        ]
      }.to_json
    )
    if email_post.status != 202
      raise "Error sending email: #{email_post.body}"
    end
  end

  def headers
    return { 'Authorization' => bearer_token }
  end
end

if __FILE__ == $0
  Run.new(bearer_token: ENV.fetch('BEARER_TOKEN'), device_tool_id: ENV.fetch('DEVICE_TOOL_ID')).run
end

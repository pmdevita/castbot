require 'rss'
require 'net/ftp' # for ftp uploads later
require 'mp3info'
require 'fileutils'
require_relative './config/config.rb'

Dir.chdir(File.expand_path(File.dirname(__FILE__)))
today = Time.new
date_string = today.strftime("%Y-%m-%d")
test_no = Dir.entries('./mp3').length-3
mp3file = "#{date_string}_test#{test_no}.mp3"
rss_feed = []
pubDate = today.strftime("%a, %d %b %Y %H:%M:%S %Z") #Sun, 08 May 2016 12:00:00 EST

# Shell command to create the audio in ChucK (-s for silent)
make_wav = "chuck Machine-test.ck -s"

# Shell command to convert to mp3 and assign it today's date
make_mp3 = "ffmpeg -i wav/temp.wav mp3/#{mp3file}"

# Run shell commands
`#{make_wav}`
`#{make_mp3}`

# Edit mp3 metadata
artfile = File.new('castbot-art.png','rb')
Mp3Info.open("./mp3/#{mp3file}") do |mp3|
    mp3.tag.title = mp3file
    mp3.tag.artist = "David MacDonald"
    mp3.tag2.add_picture(artfile.read)
end


# Upload the mp3 to effing.work (may change to davidmacdonaldmusic.com or new domain)
ftp = Net::FTP.new($ftpserver['host'],$ftpserver['id'],$ftpserver['pw'])
ftp.chdir($ftpserver['remote_root'])
ftp.putbinaryfile("./mp3/#{mp3file}","./mp3/#{mp3file}")
ftp.close

mp3_size = File.size?("./mp3/#{mp3file}")
mp3_dur = 0
Mp3Info.open("./mp3/#{mp3file}") do |info|
    mp3_dur = info.length.round
end

# If archive directory does not exist, create it
archive_dir = ("_feedarchive")
unless File.directory?(archive_dir)
    FileUtils.mkdir_p(archive_dir)
end

# For safety, make an old copy of the feed.
old_feed = "#{archive_dir}/castbot-feed_old_#{date_string}.xml"
File.rename("castbot-feed.xml",old_feed)

# Read current feed into array, line by line
File.open(old_feed, 'r') do |feedin|
    feedin.each_line {|line| rss_feed << line}
        ### save each line to an array
end

# Build new item
new_item = [
    "    <item>",
    "      <title>#{mp3file}</title>",
    "      <description>Generated #{date_string}</description>",
    "      <pubDate>#{pubDate}</pubDate>",
    "      <itunes:image href=\"http://effing.work/castbot/castbot-art.png\" />",
    "      <itunes:keywords>music,robot,experimental,art,bot,electroacoustic,ChucK</itunes:keywords>",
    "      <itunes:duration>00:00:#{mp3_dur}</itunes:duration>",
    "      <itunes:author>David MacDonald</itunes:author>",
    "      <itunes:explicit>no</itunes:explicit>",
    "      <itunes:subtitle>Generated #{date_string}</itunes:subtitle>",
    "      <itunes:summary>Generated #{date_string}</itunes:summary>",
    "      <enclosure url=\"http://effing.work/castbot/mp3/#{mp3file}\" length=\"#{mp3_size}\" type=\"audio/mpeg\" />",
    "    </item>"
]

# Insert new item into feed array and flatten it.
rss_feed.insert(28,new_item)
rss_feed.flatten

# Write out the new RSS feed
File.open("castbot-feed.xml",'w') do |feedout|
    feedout.puts rss_feed
end

# Upload the new feed to the server!
ftp = Net::FTP.new($ftpserver['host'],$ftpserver['id'],$ftpserver['pw'])
ftp.chdir($ftpserver['remote_root'])
ftp.putbinaryfile("castbot-feed.xml","castbot-feed.xml")
ftp.close

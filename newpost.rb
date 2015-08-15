require 'date'
require 'time'

puts 'What would you like to write about?'
article_title = gets.chop
slug = article_title.downcase.strip.gsub(' ', '-')

puts 'Is it a external link post? If so, what\'s the external URL?\n(leave blank if it\'s NOT a external link post)'
external_url = gets

current_date = Date.today.to_s
current_time = Time.now

filename = current_date + '-' + slug + '.md'

File.open("_posts/"+filename, "w") do |post|
  post.write("---\n")
  post.write("layout: post\n")
  post.write("title: \"" + article_title + "\"\n")
  post.write("date: #{current_time}\n")
  if (!external_url.chomp.empty?)
    post.write("external_url: #{external_url}")
  end
  post.write("---")
end

puts 'Created new file here: _/posts/'+filename

# fire up sublime text
%x(sublime '_posts/#{filename}')

require 'fileutils'

title = ARGV[0]
date = Time.now.strftime("%Y-%m-%d")

draft = "./_drafts/#{title}.md"
post = "./_posts/#{date}-#{title}.md"

FileUtils.mv(draft, post)

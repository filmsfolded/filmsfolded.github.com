require "scrape"

post_directory = "../_posts/"
imdb_comments = "http://www.imdb.com/user/ur0643062/comments-index?start=0&count=10000&summary=off&order=date"

# get all tedg comments from imdb
puts "Finding comments on IMDB"
puts imdb_comments
posts = ImdbScrape::user_comments_more(imdb_comments)
puts "Found #{posts.length} comments\n\n"

# limit for testing
# posts = posts[0..5]



posts = posts.each do |post|
  
  file_name = "#{post["comment_date"].to_s}-#{post["movie_title"].gsub(/[^\w]/,"-")}.md"
  
  unless File.exists?(post_directory+file_name)
    
    # check that it's not corrupted (some imdb error here)
    next if post["movie_title"] == "tt0500090"
    
    puts "Creating: #{file_name}"
    
    # scrape more stuff
    comment = Tedg::parse_comment(ImdbScrape::comment(post["comment"]))
    imdb = ImdbScrape::movie(comment["movie"])
    tmdb = TmdbScrape::movie_by_imdb(comment["movie"])
    
    # put together the file
    s = ""
    s += "---\n"
    
    s += "movie title: #{imdb["name"]}\n"
    s += "comment title: #{comment["name"]}\n"
    s += "rating: #{comment["rating"]}\n"
    
    s += "\n"
    
    s += "movie imdb link: #{imdb["imdb"]}\n"
    s += "movie year: #{imdb["year"]}\n"
    s += "comment imdb link: #{comment["imdb"]}\n"
    s += "movie tmdb link: #{tmdb["tmdb"]}\n"
    s += "movie tmdb trailer: #{tmdb["trailer"]}\n"
    s += "movie tmdb poster: #{tmdb["poster"]}\n"
    
    s += "\n"
    
    s += "layout: comment\n"
    s += "---\n\n"
    
    s += comment["content"]
    
    # write it
    File.open(post_directory+file_name, 'w') {|f| f.write(s) }
  end
end

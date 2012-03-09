require "rubygems"
require "nokogiri"
require "open-uri"
require "date"


#######################################
# Utility
#######################################

class Array
  def group_by(&block)
    grouped = {}
    self.each do |value|
      key = block.call(value)
      if grouped[key]
        grouped[key] << value
      else
        grouped[key] = [value]
      end
    end
    grouped
  end
  
  def remove_duplicates(&block)
    already = {}
    ret = []
    self.each do |value|
      key = block.call(value)
      if not already[key]
        already[key] = true
        ret << value
      end
    end
    ret
  end
end

class Nokogiri::XML::Node
  def stringify
    serialize(:encoding => 'UTF-8')
  end
end
class Nokogiri::XML::NodeSet
  def stringify
    map { |x| x.stringify }.join
  end
end

module Fetch
  def self.fetch(url)
    begin
      html = Nokogiri::HTML(open(url))
      yield(html)
    rescue
      puts "Unable to process URL: #{url}"
      nil
    end
  end
end


#######################################
# Generic scraping, Imdb, Tmdb
#######################################

module ImdbScrape
  def self.user_comments(imdb)
    # imdb should be like: "http://www.imdb.com/user/ur0643062/comments-index?start=0&summary=off&order=date"
    Fetch.fetch(imdb) do |html|
      html.xpath("//*[@id='outerbody']//a[contains(@href, '/reviews-')]").map {|x| "http://www.imdb.com" + x["href"]}
    end
  end
  
  def self.user_comments_more(imdb)
    # imdb should be like: "http://www.imdb.com/user/ur0643062/comments-index?start=0&summary=off&order=date"
    Fetch.fetch(imdb) do |html|
      html.xpath("//*[@id='outerbody']//a[contains(@href, '/reviews-')]").map do |x|
        {
          "movie_title" => x.xpath("text()").stringify,
          "comment_date" => Date.parse(x.xpath("parent::*/small/text()").stringify),
          "comment" => "http://www.imdb.com" + x["href"]
        }
      end
    end
  end
  
  def self.comment(imdb)
    # imdb should be like: "http://www.imdb.com/title/tt0780504/reviews-366"
    Fetch.fetch(imdb) do |html|
      {
        "name" => html.xpath("//*[@id='tn15content']//hr[1]/following::b[1]/text()").stringify,
        "date" => Date.parse(html.xpath("//*[@id='tn15content']//hr[1]/following::b[1]/following::small[1]/text()").stringify),
        "content" => html.xpath("//*[@id='tn15content']//hr[2]/preceding::p[1]").inner_html(:encoding => 'UTF-8').gsub("\n", " ").gsub("\302\227", "--").gsub(/<br>/, "\n"),
        "movie" => imdb.split("reviews-")[0],
        "imdb" => imdb,
      }
    end
  end
  
  def self.movie(imdb)
    # imdb should be like: "http://www.imdb.com/title/tt0046478/"
    Fetch.fetch(imdb) do |html|
      {
        "name" => html.xpath("//h1[@class='header']/span/preceding-sibling::text()").stringify.strip,
        "year" => html.xpath("//h1[@class='header']/descendant::a[1]/text()").stringify,
        "imdb" => imdb,
        # TODO: also known as broken
        # "also_known_as" => html.xpath("//*[text() = 'Also Known As:']/following-sibling::*[1]/text()").stringify.scan(/"([^"]*)" -/).flatten,
        # TODO: amazon, netflix
      }
    end
  end
end



module TmdbScrape
  API_KEY = "6219fd7c702fd61b68d8c3235c18c3a5"
  
  def self.movie(tmdb)
    # tmdb should be like: "http://www.themoviedb.org/movie/14696"
    Fetch.fetch("http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/#{API_KEY}/#{tmdb.split("/").last}") do |html|
      {
        "tmdb" => tmdb,
        "trailer" => html.xpath("//movie/trailer/text()").stringify,
        "poster" => html.xpath("//movie/images/image[@type='poster'][@size='original'][1]/@url").to_s,
        "people" => html.xpath("//movie/cast/person").map do |person|
          {
            "name" => person["name"],
            "tmdb" => "http://www.themoviedb.org/person/" + person["id"],
            "character" => person["character"],
            "job" => person["job"],
          }
        end,
      }
    end
  end
  
  def self.movie_by_imdb(imdb)
    # imdb should be like: "http://www.imdb.com/title/tt0046478/"
    Fetch.fetch("http://api.themoviedb.org/2.1/Movie.imdbLookup/en/xml/#{API_KEY}/#{imdb.split("/").last}") do |html|
      tmdb_id = html.xpath("//movie/id/text()").to_s
      if tmdb_id != ""
        tmdb = "http://www.themoviedb.org/movie/" + tmdb_id
        self.movie(tmdb)
      else
        {}
      end
    end
  end
end


#######################################
# Some tests to show how these work:
# p ImdbScrape::user_comments("http://www.imdb.com/user/ur0643062/comments-index?start=0&summary=off&order=date")
# p ImdbScrape::user_comments_more("http://www.imdb.com/user/ur0643062/comments-index?start=0&summary=off&order=date")
# p ImdbScrape::user_comments("http://www.imdb.com/user/ur0643062/comments-index?start=0&count=10000&summary=off&order=date")[0..100]
# p ImdbScrape::comment("http://www.imdb.com/title/tt0780504/reviews-366")
# p ImdbScrape::movie("http://www.imdb.com/title/tt0046478/")
# p TmdbScrape.movie_by_imdb("http://www.imdb.com/title/tt0046478/")
#######################################



#######################################
# Tedg related code
#######################################

module Tedg
  def self.parse_comment(comment)
    # should be a comment (the result from ImdbScrape::comment)
    
    # formatting
    comment["content"] = comment["content"].gsub(/`/, "'")
    
    # parse Ted's rating, strip it out
    teds_eval = comment["content"].split("Ted's Evaluation -- ")
    if teds_eval.length == 2
      comment["rating"] = teds_eval[1][0,1].to_i
      comment["content"] = teds_eval[0]
    end
    
    comment["content"] = comment["content"].strip
    
    comment
  end
end


#######################################
# Some tests to show how these work:
# p Tedg::parse_comment(ImdbScrape::comment("http://www.imdb.com/title/tt0120891/reviews-449"))
# p Tedg::parse_comment(ImdbScrape::comment("http://www.imdb.com/title/tt0433035/reviews-286"))
#######################################




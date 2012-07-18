class Tweet < ActiveRecord::Base

  ##############################################################################
  attr_accessible(:twitter_user, :tweeted_text, :tweeted_at)

  ##############################################################################
  validates(:twitter_user, presence: true)
  validates(:tweeted_at,   presence: true)

  ##############################################################################
  belongs_to(:user)
  has_and_belongs_to_many(:categories)

  ##############################################################################
  # This is my favorite version.  It's fast and uses inject to avoid a
  # temporary variable.  In order to avoid pulling a list of
  # categories that could be larger than the available amount of
  # memory the database query is limited to 50 results by default.
  #
  # This introduces a limitation that when there are a large number of
  # categories only the first 50 will be considered when looking for
  # matches.
  def suggested_categories (max=50)
    words = tweeted_text.downcase.gsub(/#/, '').split(/\s+/)
    categories = Category.limit(max).all

    words.inject([]) do |collector, word|
      match = categories.detect do |cat|
        cat.title.downcase == word
      end

      collector << match.title if match
      collector
    end.sort.uniq.join(', ')
  end

  ##############################################################################
  # This version is identical to the previous one except that it uses
  # a temporary local variable instead of inject.  This version has
  # the same limitations as well.
  def suggested_categories_no_inject (max=50)
    words = tweeted_text.downcase.gsub(/#/, '').split(/\s+/)
    categories = Category.limit(max).all
    results = []

    words.each do |word|
      match = categories.detect do |cat|
        cat.title.downcase == word
      end

      results << match.title if match
    end

    results.sort.uniq.join(', ')
  end

  ##############################################################################
  # This version is significantly slower since it does one database
  # query for each word in the tweeted text.  One advantage is that it
  # doesn't have the same limitations that the previous versions do
  # with respect to a limited size of categories.
  def suggested_categories_slow
    words = tweeted_text.downcase.gsub(/#/, '').split(/\s+/)

    words.inject([]) do |collector, word|
      match = Category.where('LOWER(title) = ?', word).first
      collector << match.title if match
      collector
    end.sort.uniq.join(', ')
  end

  ##############################################################################
  # This version is the same as above without using inject.
  def suggested_categories_slow_no_inject
    words = tweeted_text.downcase.gsub(/#/, '').split(/\s+/)
    results = []

    words.each do |word|
      match = Category.where('LOWER(title) = ?', word).first
      results << match.title if match
    end

    results.sort.uniq.join(', ')
  end

  ##############################################################################
  # Very similar to the first version except it uses Array#index
  # instead of Array#detect.
  def suggested_categories_using_index (max=50)
    words = tweeted_text.downcase.gsub(/#/, '').split(/\s+/)
    categories = Category.limit(max).all
    titles = categories.map {|c| c.title.downcase}

    words.inject([]) do |collector, word|
      i = titles.index(word)
      collector << categories[i].title if i
      collector
    end.sort.uniq.join(', ')
  end

  ##############################################################################
  # This version is pretty nice, I may actually like this one better
  # than the first one.  This version makes the database do all the
  # heavy lifting by finding all categories whose titles are in our
  # list of words.
  def suggested_categories_database
    words = tweeted_text.downcase.gsub(/#/, '').split(/\s+/).sort.uniq
    cats = Category.where('LOWER(title) in (?)', words).order(:title)
    cats.map(&:title).join(', ')
  end
end

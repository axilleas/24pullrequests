class Project < ActiveRecord::Base

  LANGUAGES = ["ABAP", "ActionScript", "Ada", "Apex", "AppleScript", "Arc",
               "Arduino", "ASP", "Assembly", "Augeas", "AutoHotkey", "Awk", "Bluespec",
               "Boo", "Bro", "C", "C#", "C++", "Ceylon", "Chisel", "CLIPS", "Clojure",
               "COBOL", "CoffeeScript", "ColdFusion", "Common Lisp", "Coq",
               "CSS", "D", "Dart", "DCPU-16 ASM", "DOT", "Dylan", "eC", "Ecl",
               "Eiffel", "Elixir", "Elm", "Emacs Lisp", "Erlang", "F#",
               "Factor", "Fancy", "Fantom", "Forth", "FORTRAN", "Go", "Gosu",
               "Groovy", "Haskell", "Haxe", "HTML", "Io", "Ioke", "J", "Java",
               "JavaScript", "Julia", "Kotlin", "Lasso", "LiveScript", "Logos",
               "Logtalk", "Lua", "M", "Markdown", "Matlab", "Max", "Mirah",
               "Monkey", "MoonScript", "Nemerle", "Nimrod", "Nu",
               "Objective-C", "Objective-J", "OCaml", "Omgrofl", "ooc", "Opa",
               "OpenEdge ABL", "Parrot", "Pascal", "Perl", "Perl 6", "PHP", "Pike",
               "PogoScript", "PowerShell", "Processing", "Prolog", "Puppet",
               "Pure Data", "Python", "R", "Racket", "Ragel in Ruby Host",
               "Rebol", "Rouge", "Ruby", "Rust", "Scala", "Scheme", "Scilab",
               "Self", "Shell", "Slash", "Smalltalk", "Squirrel",
               "Standard ML", "SuperCollider", "Swift", "Tcl", "Turing", "TXL",
               "TypeScript", "Vala", "Verilog", "VHDL", "VimL", "Visual Basic",
               "Volt", "wisp", "XC", "XML", "XProc", "XQuery", "XSLT", "Xtend"]

  has_many :project_labels
  has_many :labels, through: :project_labels

  belongs_to :submitted_by, class_name: "User", foreign_key: :user_id

  validates_presence_of :description, :github_url, :name, :main_language
  validates_format_of :github_url, :with => /\Ahttps?:\/\/(www\.)?github.com\/[\w-]*\/[\w\.-]*(\/)?\Z/i, :message => 'Enter a valid GitHub URL.'
  validates_uniqueness_of :github_url, :case_sensitive => false, :message => "Project has already been suggested."
  validates_length_of :description, :within => 20..200
  validates_inclusion_of :main_language, :in => LANGUAGES, :message => 'must be a programming language'

  scope :not_owner, lambda {|user| where("github_url" != "github.com/#{user}/") }
  scope :by_language, ->(language) { where("lower(main_language) =?", language.downcase) }
  scope :by_languages, ->(languages) { where("lower(main_language) IN (?)", languages) }
  scope :by_labels, ->(labels) { joins(:labels).where("labels.name  IN (?)", labels).select("distinct(projects.id), projects.*") }
  scope :active, -> { where(inactive: [ false, nil ]) }

  accepts_nested_attributes_for :labels,  reject_if: proc { |attributes| attributes['id'].blank? }

  paginates_per 20

  def self.find_by_github_repo(repository)
    filter_by_repository(repository).first
  end

  def self.filter_by_repository(repository)
    Project.where("github_url like ?", "%#{repository}%")
  end

  def github_repository
    self.github_url.gsub(/^(((https|http|git)?:\/\/(www\.)?)|git@)github.com(:|\/)/i, '').gsub(/(\.git|\/)$/i, '')
  end

  def deactivate!
    update_attribute(:inactive, true)
  end

  def issues(nickname, token, months_ago=6, options={})
    date = (Time.zone.now - months_ago.months).utc.iso8601
    options.merge! since: date

    GithubClient.new(nickname, token).issues(github_repository, options)
  end

  def commits(nickname, token, months_ago=3, options={})
    date = (Time.zone.now - months_ago.months).utc.iso8601
    options.merge! since: date
    options.merge! sha: "master"

    GithubClient.new(nickname, token).commits(github_repository, options)
  end

  def repo(nickname, token)
    GithubClient.new(nickname, token).repository(github_repository)
  end

  def score(nickname, token)
    PopularityScorer.new(nickname, token, self).score
  end
end

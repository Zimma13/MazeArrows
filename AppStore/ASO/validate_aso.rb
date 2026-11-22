# frozen_string_literal: true

require "unicode_normalize/normalize"
require "json"

ROOT = File.expand_path(__dir__)
EXPECTED_LOCALES = %w[en-US ja de-DE ko zh-Hant pt-BR pt-PT es-MX fr-FR fr-CA en-GB en-CA en-AU es-ES].freeze
REQUIRED_KEYS = %w[LOCALE LANGUAGE APP_NAME SUBTITLE PROMOTIONAL_TEXT KEYWORDS SUPPORT_URL PRIVACY_POLICY_URL MARKETING_URL WHATS_NEW].freeze

def graphemes(value)
  value.scan(/\X/).length
end

def tokens(value)
  value.unicode_normalize(:nfc).downcase.scan(/\p{L}[\p{L}\p{M}\p{N}]*/)
end

def read_metadata(path)
  File.readlines(path, chomp: true).filter_map do |line|
    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    [key, value] if key && value
  end.to_h
end

errors = []
stats = []

EXPECTED_LOCALES.each do |locale|
  dir = File.join(ROOT, locale)
  metadata_path = File.join(dir, "metadata.txt")
  description_path = File.join(dir, "description.txt")
  errors << "#{locale}: retired subscription listing in release inputs" if File.exist?(File.join(dir, "subscriptions.txt"))

  unless File.file?(metadata_path)
    errors << "#{locale}: metadata.txt missing"
    next
  end
  unless File.file?(description_path)
    errors << "#{locale}: description.txt missing"
    next
  end

  data = read_metadata(metadata_path)
  missing = REQUIRED_KEYS.reject { |key| data.key?(key) }
  errors << "#{locale}: missing #{missing.join(', ')}" unless missing.empty?
  next unless missing.empty?

  blank = REQUIRED_KEYS.select { |key| data[key].strip.empty? }
  errors << "#{locale}: empty #{blank.join(', ')}" unless blank.empty?
  errors << "#{locale}: LOCALE mismatch" unless data["LOCALE"] == locale
  errors << "#{locale}: APP_NAME #{graphemes(data['APP_NAME'])}/30 characters" if graphemes(data["APP_NAME"]) > 30
  errors << "#{locale}: SUBTITLE #{graphemes(data['SUBTITLE'])}/30 characters" if graphemes(data["SUBTITLE"]) > 30
  errors << "#{locale}: PROMOTIONAL_TEXT #{graphemes(data['PROMOTIONAL_TEXT'])}/170 characters" if graphemes(data["PROMOTIONAL_TEXT"]) > 170
  errors << "#{locale}: KEYWORDS #{data['KEYWORDS'].bytesize}/100 bytes" if data["KEYWORDS"].bytesize > 100
  errors << "#{locale}: KEYWORDS contains a space after comma" if data["KEYWORDS"].match?(/,\s/)

  keyword_terms = data["KEYWORDS"].split(",")
  normalized_terms = keyword_terms.map { |term| term.unicode_normalize(:nfc).downcase }
  short_terms = keyword_terms.select { |term| graphemes(term) <= 2 }
  errors << "#{locale}: keyword terms must exceed two characters: #{short_terms.join(', ')}" unless short_terms.empty?
  duplicates = normalized_terms.tally.select { |_term, count| count > 1 }.keys
  errors << "#{locale}: duplicate keyword terms #{duplicates.join(', ')}" unless duplicates.empty?

  name_tokens = tokens(data["APP_NAME"])
  subtitle_tokens = tokens(data["SUBTITLE"])
  keyword_tokens = tokens(data["KEYWORDS"])
  overlap_name_subtitle = name_tokens & subtitle_tokens
  overlap_name_keywords = name_tokens & keyword_tokens
  overlap_subtitle_keywords = subtitle_tokens & keyword_tokens

  errors << "#{locale}: Name/Subtitle overlap #{overlap_name_subtitle.join(', ')}" unless overlap_name_subtitle.empty?
  errors << "#{locale}: Name/Keywords overlap #{overlap_name_keywords.join(', ')}" unless overlap_name_keywords.empty?
  errors << "#{locale}: Subtitle/Keywords overlap #{overlap_subtitle_keywords.join(', ')}" unless overlap_subtitle_keywords.empty?

  search_surface = (data["APP_NAME"] + data["SUBTITLE"]).unicode_normalize(:nfc).downcase
  cjk_repeats = normalized_terms.select { |term| term.match?(/[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]/) && search_surface.include?(term) }
  errors << "#{locale}: CJK keyword repeats search text #{cjk_repeats.join(', ')}" unless cjk_repeats.empty?

  description = File.read(description_path).strip
  errors << "#{locale}: empty description" if description.empty?
  errors << "#{locale}: description #{graphemes(description)}/4000 characters" if graphemes(description) > 4000

  news = data.fetch("WHATS_NEW")
  errors << "#{locale}: release notes exceed 4000 characters" if graphemes(news) > 4000
  errors << "#{locale}: missing new chapter in description or release notes" unless description.include?("260") && news.include?("20")
  visible = [description, news, data["APP_NAME"], data["SUBTITLE"], data["PROMOTIONAL_TEXT"]].join(" ")
  errors << "#{locale}: obsolete 1.0 copy" if visible.match?(/Premium|240|NOT_AVAILABLE_FOR_VERSION/i)

  { "SUPPORT_URL" => "support/", "PRIVACY_POLICY_URL" => "privacy/", "MARKETING_URL" => "" }.each do |key, suffix|
    errors << "#{locale}: unexpected #{key}" unless data[key] == "https://kinapp.dev/arrowmaze/#{suffix}"
  end

  stats << [
    locale,
    "name #{graphemes(data['APP_NAME'])}/30",
    "subtitle #{graphemes(data['SUBTITLE'])}/30",
    "promo #{graphemes(data['PROMOTIONAL_TEXT'])}/170",
    "keywords #{data['KEYWORDS'].bytesize}/100 bytes",
    "description #{graphemes(description)}/4000",
    "what's new #{graphemes(news)}/4000"
  ].join(" | ")

end

media = File.expand_path("../ScreenshotSources/v2", ROOT)
manifest = JSON.parse(File.read(File.join(media, "storefronts.json")))
errors << "wrong media version" unless manifest["appVersion"] == "2.0"
sets = manifest.fetch("sets")
mapped = sets.values.flat_map { |entry| entry.fetch("storefronts") }
errors << "screenshot locale coverage or duplicates" unless mapped.sort == EXPECTED_LOCALES.sort
previews = Dir.glob(File.join(ROOT, "previews", "*.txt")).map { |path| File.basename(path, ".txt") }
errors << "preview language coverage" unless previews.sort == sets.keys.sort
sets.each_key do |language|
  config_path = File.join(media, "screenshots.#{language}.json")
  preview_path = File.join(ROOT, "previews", "#{language}.txt")
  unless File.file?(config_path) && File.file?(preview_path)
    errors << "#{language}: missing screenshot captions or preview script"
    next
  end
  slides = JSON.parse(File.read(config_path)).fetch("slides")
  errors << "#{language}: screenshot sequence" unless slides.map { |slide| slide["id"] } == %w[photoMaze freeArrow combo worlds daily]
  headline = slides.find { |slide| slide["id"] == "worlds" }&.fetch("headline", [])&.join(" ").to_s
  errors << "#{language}: incorrect campaign screenshot" unless headline.include?("260") && headline.include?("8")
  script = File.read(preview_path)
  errors << "#{language}: incorrect campaign preview" unless script.lines.any? { |line| line.include?("260") && line.include?("8") }
  errors << "#{language}: old content in media" if (slides.to_json + script).match?(/240|Premium/i)
end

puts "Checked #{EXPECTED_LOCALES.length} locales and #{sets.length} language sets for version 2.0"
puts "ERRORS: #{errors.length}"
errors.each { |error| puts "  - #{error}" }
puts "LIMITS"
stats.each { |stat| puts "  #{stat}" }

exit(errors.empty? ? 0 : 1)

# frozen_string_literal: true

require "unicode_normalize/normalize"

ROOT = File.expand_path(__dir__)
EXPECTED_LOCALES = %w[en-US ja de-DE ko zh-Hant pt-BR es-MX fr-FR en-GB en-CA en-AU es-ES].freeze
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
warnings = []
stats = []

EXPECTED_LOCALES.each do |locale|
  dir = File.join(ROOT, locale)
  metadata_path = File.join(dir, "metadata.txt")
  description_path = File.join(dir, "description.txt")
  subscription_path = File.join(dir, "subscriptions.txt")

  %w[screenshots.txt app-preview.txt subscriptions.txt].each do |filename|
    errors << "#{locale}: #{filename} missing" unless File.file?(File.join(dir, filename))
  end

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

  if File.file?(subscription_path)
    subscription = read_metadata(subscription_path)
    %w[WEEKLY_DISPLAY_NAME ANNUAL_DISPLAY_NAME].each do |key|
      errors << "#{locale}: #{key} missing" unless subscription[key]
      errors << "#{locale}: #{key} #{graphemes(subscription[key])}/30 characters" if subscription[key] && graphemes(subscription[key]) > 30
    end
    %w[WEEKLY_DESCRIPTION ANNUAL_DESCRIPTION].each do |key|
      errors << "#{locale}: #{key} missing" unless subscription[key]
      errors << "#{locale}: #{key} #{graphemes(subscription[key])}/45 characters" if subscription[key] && graphemes(subscription[key]) > 45
    end
  end

  stats << [
    locale,
    "name #{graphemes(data['APP_NAME'])}/30",
    "subtitle #{graphemes(data['SUBTITLE'])}/30",
    "promo #{graphemes(data['PROMOTIONAL_TEXT'])}/170",
    "keywords #{data['KEYWORDS'].bytesize}/100 bytes",
    "description #{graphemes(description)}/4000"
  ].join(" | ")

  warnings << "#{locale}: SUPPORT_URL is not ready" if data["SUPPORT_URL"].include?("REQUIRED")
  warnings << "#{locale}: PRIVACY_POLICY_URL is not ready" if data["PRIVACY_POLICY_URL"].include?("REQUIRED")
end

puts "Checked #{EXPECTED_LOCALES.length} locales"
puts "ERRORS: #{errors.length}"
errors.each { |error| puts "  - #{error}" }
puts "WARNINGS: #{warnings.length}"
warnings.each { |warning| puts "  - #{warning}" }
puts "LIMITS"
stats.each { |stat| puts "  #{stat}" }

exit(errors.empty? ? 0 : 1)

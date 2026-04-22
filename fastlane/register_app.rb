#!/usr/bin/env ruby
# Register the App ID in Apple Developer and create the App Store Connect
# listing for Bike Action Denver. Idempotent: skips whichever step is
# already done. Uses the App Store Connect REST API directly with our
# existing .p8 API key (no Apple-ID login / 2FA needed).
#
# Usage (from repo root):
#   ruby fastlane/register_app.rb
#
# Required env vars:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILEPATH

require "json"
require "net/http"
require "openssl"
require "base64"
require "uri"

APP_IDENTIFIER = "ink.sam.bikelanes"
APP_NAME       = "Bike Action Denver"
SKU            = "bike-action-denver"
PRIMARY_LOCALE = "en-US"
PLATFORM       = "IOS"

KEY_ID       = ENV.fetch("ASC_KEY_ID")
ISSUER_ID    = ENV.fetch("ASC_ISSUER_ID")
KEY_FILEPATH = File.expand_path(ENV.fetch("ASC_KEY_FILEPATH"))

# --- JWT signing --------------------------------------------------------
def jwt_token
  header  = { alg: "ES256", kid: KEY_ID, typ: "JWT" }
  payload = { iss: ISSUER_ID,
              iat: Time.now.to_i,
              exp: Time.now.to_i + 10 * 60,
              aud: "appstoreconnect-v1" }
  signing_input = [header, payload].map { |h| b64url(JSON.dump(h)) }.join(".")
  pkey = OpenSSL::PKey::EC.new(File.read(KEY_FILEPATH))
  der  = pkey.sign(OpenSSL::Digest.new("SHA256"), signing_input)
  sig  = ecdsa_der_to_raw(der)
  "#{signing_input}.#{b64url(sig)}"
end

def b64url(bytes)
  Base64.urlsafe_encode64(bytes).tr("=", "")
end

# ASN.1 DER → fixed-length 64-byte (r||s) signature required by ES256.
def ecdsa_der_to_raw(der)
  asn = OpenSSL::ASN1.decode(der)
  r, s = asn.value.map { |v| v.value.to_s(2) }
  r = ("\x00" * (32 - r.bytesize)) + r
  s = ("\x00" * (32 - s.bytesize)) + s
  r + s
end

# --- HTTP helpers -------------------------------------------------------
def asc_request(method, path, body: nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true
  cls = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
  req = cls.new(uri)
  req["Authorization"] = "Bearer #{jwt_token}"
  req["Accept"]       = "application/json"
  if body
    req["Content-Type"] = "application/json"
    req.body = JSON.dump(body)
  end
  res = http.request(req)
  data = res.body.empty? ? {} : JSON.parse(res.body)
  [res.code.to_i, data]
end

# --- Registration steps -------------------------------------------------
def find_bundle_id
  status, body = asc_request(:get,
    "/v1/bundleIds?filter[identifier]=#{APP_IDENTIFIER}&limit=1")
  abort "bundleIds GET #{status}: #{body}" unless status == 200
  body["data"]&.first
end

def create_bundle_id
  status, body = asc_request(:post, "/v1/bundleIds", body: {
    data: {
      type: "bundleIds",
      attributes: {
        identifier: APP_IDENTIFIER,
        name:       APP_NAME,
        platform:   PLATFORM,
        seedId:     nil,
      },
    },
  })
  abort "bundleIds POST #{status}: #{body}" unless status == 201
  body["data"]
end

def find_app
  status, body = asc_request(:get,
    "/v1/apps?filter[bundleId]=#{APP_IDENTIFIER}&limit=1")
  abort "apps GET #{status}: #{body}" unless status == 200
  body["data"]&.first
end

def create_app(bundle_id_relation_id)
  status, body = asc_request(:post, "/v1/apps", body: {
    data: {
      type: "apps",
      attributes: {
        name:          APP_NAME,
        sku:           SKU,
        primaryLocale: PRIMARY_LOCALE,
      },
      relationships: {
        bundleId: { data: { type: "bundleIds", id: bundle_id_relation_id } },
      },
    },
  })
  abort "apps POST #{status}: #{body}" unless status == 201
  body["data"]
end

# --- Run ----------------------------------------------------------------
puts "→ checking Apple Developer bundle ID #{APP_IDENTIFIER}"
bundle = find_bundle_id
if bundle
  puts "  ✓ already registered (id=#{bundle["id"]})"
else
  puts "  + creating…"
  bundle = create_bundle_id
  puts "  ✓ created (id=#{bundle["id"]})"
end

puts "→ checking App Store Connect listing for #{APP_IDENTIFIER}"
app = find_app
if app
  puts "  ✓ already exists (id=#{app["id"]}, name=#{app["attributes"]["name"]})"
else
  puts "  + creating…"
  app = create_app(bundle["id"])
  puts "  ✓ created (id=#{app["id"]}, name=#{app["attributes"]["name"]})"
end

puts "\nThe bundle ID is now selectable in App Store Connect, and the listing is live."
puts "Visit: https://appstoreconnect.apple.com/apps/#{app["id"]}/distribution"

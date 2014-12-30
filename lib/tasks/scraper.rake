namespace :scraper do
  desc "Fetch Craigslist posts from 3Taps"
  task scrape: :environment do
  	require 'open-uri'
		require 'json'

		# set api tokeand url
		auth_token = "19290a94a1bc7198dcc258b553f58e2c"
		polling_url = "http://polling.3taps.com/poll"

		# Grab data until up-to-date
		loop do

			# specificy request parameters
			params = {
				auth_token: auth_token, 
				anchor: Anchor.first.value,
				source: "CRAIG",
				category_group: "RRRR",
				category: "RHFR",
				'location.city' => "USA-NYM-BRL",
				retvals: "location,external_url,heading,body,timestamp,price,images,annotations"
			}

			# prepare API request
			uri = URI.parse(polling_url)
			uri.query = URI.encode_www_form(params)

			#submit request
			result = JSON.parse(open(uri).read)

			#display results to screen
			# puts result["postings"].first["images"].first["full"]

			#store results in database
			result["postings"].each do |posting|

				#create new post
				@post = Post.new
				@post.heading = posting["heading"]
				@post.body = posting["body"]
				@post.price = posting["price"]
				@post.neighborhood = Location.find_by(code: posting["location"]["locality"]).try(:name)
				@post.external_url = posting["external_url"]
				@post.timestamp = posting["timestamp"]
				@post.bedrooms = posting["annotations"]["bedrooms"] if posting["annotations"]["bedrooms"].present?
				@post.bathrooms = posting["annotations"]["bathrooms"] if posting["annotations"]["bathrooms"].present?
				@post.sqft = posting["annotations"]["sqft"] if posting["annotations"]["sqft"].present?
				@post.cats = posting["annotations"]["cats"] if posting["annotations"]["cats"].present?
				@post.dogs = posting["annotations"]["dogs"] if posting["annotations"]["dogs"].present?
				@post.w_d_in_unit = posting["annotations"]["w_d_in_unit"] if posting["annotations"]["w_d_in_unit"].present?
				@post.street_parking = posting["annotations"]["street_parking"] if posting["annotations"]["street_parking"].present?

				#save the post
				@post.save

				#loop over images and save to images database
				posting["images"].each do |image|
					@image = Image.new
					@image.url = image["full"]
					@image.post_id = @post.id
					@image.save
				end
			end

			Anchor.first.update(value: result["anchor"])
			puts Anchor.first.value
			break if result["postings"].empty?
		end # end loop
  end



  desc "Destroy all posting data"
  task destroy_all_posts: :environment do
  	Post.destroy_all
  end



  desc "Save neighborhood codes in a reference table"
  task scrape_neighborhoods: :environment do
  	require 'open-uri'
		require 'json'

		# set api tokeand url
		auth_token = "19290a94a1bc7198dcc258b553f58e2c"
		location_url = "http://reference.3taps.com/locations"

		# specificy request parameters
		params = {
			auth_token: auth_token, 
			level: "locality",
			city: "USA-NYM-BRL"
		}

		# prepare API request
		uri = URI.parse(location_url)
		uri.query = URI.encode_www_form(params)

		#submit request
		result = JSON.parse(open(uri).read)

		# #display results to screen
		# puts JSON.pretty_generate result

		# Store results in database
		result["locations"].each do |location|
			@location = Location.new
			@location.code = location["code"]
			@location.name = location["short_name"]
			@location.save
		end
	end 

	desc "Discard old data"
	task discard_old_data: :environment do
		Post.all.each do |post|
			if post.created.at = 6.hours_ago
				post.destroy
			end
		end
	end
end

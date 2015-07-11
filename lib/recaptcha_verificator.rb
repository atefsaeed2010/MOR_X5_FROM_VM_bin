class RecaptchaVerificator
  #Verifies reCAPTCHA public and private keys
  def self.verify_keys(public_key, private_key)
  	public_key_valid = verify_public_key(public_key)
  	private_key_valid = verify_private_key(private_key)
  	public_key_valid && private_key_valid
  end

  def self.verify_public_key(public_key)
  	uri = URI("http:#{Recaptcha.configuration.api_server_url}/challenge?k=#{public_key}&ssl=false")

  	response = Net::HTTP.get(uri)

  	unless success = response.match(/challenge : '.+'/)
  	  Action.add_action(0, 'Invalid reCAPTCHA configuration', 'reCAPTCHA public key is invalid')
  	end

  	success
  end

  def self.verify_private_key(private_key)
  	challenge = 'test_challenge'
    uri = URI.parse("http:#{Recaptcha.configuration.api_server_url}/verify?privatekey=#{private_key}&remoteip=127.0.0.1&challenge=#{challenge}&response=#{challenge}")

    response = Net::HTTP::post_form(uri, max: 500).body

    unless success = (!response.include? 'invalid-site-private-key')
      Action.add_action(0, 'Invalid reCAPTCHA configuration', 'reCAPTCHA private key is invalid')
    end

    success
  end
end
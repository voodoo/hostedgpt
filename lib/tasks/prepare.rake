namespace :db do
  desc "Setup database encryption and update credentials"
  task setup_encryption: :environment do
    ensure_master_key

    old_config = Rails.application.credentials.config
    config = old_config.deep_dup

    if config[:secret_key_base].nil? && ENV['SECRET_KEY_BASE'].nil?
      config = add_secret_key_base(config)
    end

    if config[:active_record_encryption].nil? && ENV['CONFIGURE_ACTIVE_RECORD_ENCRYPTION_FROM_ENV'] != 'true'
      config = add_active_record_encryption(config)
    end

    if config != old_config
      Rails.application.credentials.write(config.to_yaml)
      ActiveRecord::Encryption.config.primary_key = config[:active_record_encryption][:primary_key]
      ActiveRecord::Encryption.config.deterministic_key = config[:active_record_encryption][:deterministic_key]
      ActiveRecord::Encryption.config.key_derivation_salt = config[:active_record_encryption][:key_derivation_salt]
    end
  end
end

Rake::Task["db:prepare"].enhance [:setup_encryption]

def add_secret_key_base(config)
  config[:secret_key_base] = SecureRandom.hex(64)
  config
end

def add_active_record_encryption(config)
  config[:active_record_encryption] = {
    primary_key: SecureRandom.alphanumeric(32),
    deterministic_key: SecureRandom.alphanumeric(32),
    key_derivation_salt: SecureRandom.alphanumeric(32),
  }
  config
end

def encryption_init
  original_stdout = $stdout
  $stdout = StringIO.new
  Rake::Task["db:encryption:init"].invoke
  output = $stdout.string
  $stdout = original_stdout

  {
    primary_key: output.match(/primary_key: (\S+)/)[1],
    deterministic_key: output.match(/deterministic_key: (\S+)/)[1],
    key_derivation_salt: output.match(/key_derivation_salt: (\S+)/)[1],
  }
end

def ensure_master_key
  master_key_path = Rails.root.join('config', 'master.key')
  unless File.exist?(master_key_path)
    key = SecureRandom.hex(16)
    File.write(master_key_path, key)
  end
end
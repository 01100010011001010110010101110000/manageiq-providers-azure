module ManageIQ::Providers::Azure::CloudManager::Provision::Configuration
  extend ActiveSupport::Concern

  include_concern 'Disk'
  include_concern 'Instance'
  include_concern 'Network'

  def userdata_payload
    return unless raw_script = super
    Base64.encode64(raw_script)
  end
end

module ManageIQ::Providers::Azure::CloudManager::Provision::OptionsHelper
  def boot_diagnostics_uri
    get_option(:boot_diagnostics_uri)
  end

  def enable_boot_diagnostics
    get_option(:enable_boot_diagnostics)
  end

  def license_type
    get_option(:license_type)
  end

  def root_password
    MiqPassword.decrypt(options[:root_password]) if options[:root_password]
  end

  def resource_group
    @resource_group ||= ResourceGroup.find_by(:id => options[:resource_group])
  end

  def security_group
    @security_group ||= SecurityGroup.find_by(:id => get_option(:security_groups))
  end
end

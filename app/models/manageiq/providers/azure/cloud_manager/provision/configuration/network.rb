module ManageIQ::Providers::Azure::CloudManager::Provision::Configuration::Network
  def associated_nic
    floating_ip.try(:network_port).try(:ems_ref)
  end

  def create_nic
    source.with_provider_connection do |azure|
      nis             = Azure::Armrest::Network::NetworkInterfaceService.new(azure)
      ips             = Azure::Armrest::Network::IpAddressService.new(azure)
      ip              = ips.create("#{dest_name}-publicIp", resource_group.name, :location => region)
      network_options = build_nic_options(ip.id)

      return nis.create(dest_name, resource_group.name, network_options).id
    end
  end

  def build_nic_options(ip)
    network_options = {
        :location   => region,
        :properties => {
            :ipConfigurations => [
                :name       => dest_name,
                :properties => {
                    :subnet          => {
                        :id => cloud_subnet.ems_ref
                    },
                    :publicIPAddress => {
                        :id => ip
                    },
                }
            ],
        }
    }
    network_options[:properties][:networkSecurityGroup] = {:id => security_group.ems_ref} if security_group
    network_options
  end
end

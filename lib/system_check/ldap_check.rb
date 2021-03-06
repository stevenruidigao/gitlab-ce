# frozen_string_literal: true

module SystemCheck
  # Used by gitlab:ldap:check rake task
  class LdapCheck < BaseCheck
    set_name 'LDAP:'

    def multi_check
      if Gitlab::Auth::LDAP::Config.enabled?
        # Only show up to 100 results because LDAP directories can be very big.
        # This setting only affects the `rake gitlab:check` script.
        limit = ENV['LDAP_CHECK_LIMIT']
        limit = 100 if limit.blank?

        check_ldap(limit)
      else
        $stdout.puts 'LDAP is disabled in config/gitlab.yml'
      end
    end

    private

    def check_ldap(limit)
      servers = Gitlab::Auth::LDAP::Config.providers

      servers.each do |server|
        $stdout.puts "Server: #{server}"

        begin
          Gitlab::Auth::LDAP::Adapter.open(server) do |adapter|
            check_ldap_auth(adapter)

            $stdout.puts "LDAP users with access to your GitLab server (only showing the first #{limit} results)"

            users = adapter.users(adapter.config.uid, '*', limit)
            users.each do |user|
              $stdout.puts "\tDN: #{user.dn}\t #{adapter.config.uid}: #{user.uid}"
            end
          end
        rescue Net::LDAP::ConnectionRefusedError, Errno::ECONNREFUSED => e
          $stdout.puts "Could not connect to the LDAP server: #{e.message}".color(:red)
        end
      end
    end

    def check_ldap_auth(adapter)
      auth = adapter.config.has_auth?

      message = if auth && adapter.ldap.bind
                  'Success'.color(:green)
                elsif auth
                  'Failed. Check `bind_dn` and `password` configuration values'.color(:red)
                else
                  'Anonymous. No `bind_dn` or `password` configured'.color(:yellow)
                end

      $stdout.puts "LDAP authentication... #{message}"
    end
  end
end

namespace :vlad do
  def check_usage(site)
    if (site.nil? || site.size == 0)
      puts "Usage: rake vlad:custom:setup[<domain-key>]\n  e.g. rake vlad:custom:setup[www]"
      puts "       rake vlad:deploy[<domain-key>]\n  e.g. rake vlad:deploy[www]"
      exit(-1)
    end
  end

  def require_site(site)
    check_usage(site)

    set :domain, @domain_map[site]
    set :rails_env, site
  end

  def custom_release(branch)
    if (branch.nil? || branch.size == 0)
      set :branch, nil
    else
      set :release_name, release_name + "_" + branch
      set :branch, branch
    end
  end

  remote_task "seed" do
    run "cd #{current_path} && rake RAILS_ENV=#{rails_env} db:seed"
  end

  remote_task "symlink_database_yml" do
    file = "database.yml"
    run "ln -s #{shared_path}/config/#{file} #{release_path}/config/#{file}"
  end

  remote_task :set_perms do
    begin
      run [ "sudo find #{release_path} -type f -exec chmod #{file_chmod_to} {} \\;",
            "sudo find #{release_path} -type d -exec chmod #{dir_chmod_to} {} \\;",
            "sudo chown -R #{chown_to} #{release_path}"].join(" && ")
    rescue => e
      raise e
    end
  end

  task :bundle do
    if (application.size > 0)
      git_cmd = branch ? "git clone -b #{branch} #{git_connection}:#{application}.git /tmp/#{release_name}" :
                         "git clone #{git_connection}:#{application}.git /tmp/#{release_name}"



      sh [  "rm -rf /tmp/#{release_name}",
            git_cmd,
            "cd /tmp && tar --exclude=.git -czf #{release_name}.tgz #{release_name}"
        ].join(" && ")
    else
      puts "You must set the application name."
      exit(-1)
    end
  end

  task :transfer do
    sh "scp /tmp/#{release_name}.tgz #{domain}:/tmp"
  end

  remote_task :extract do
    begin
      run [ "cd #{releases_path}",
            "sudo tar -zxf /tmp/#{release_name}.tgz",
            "cd #{deploy_to}",
            "sudo rm -f current",
            "sudo ln -s #{release_path} current"].join(" && ")
    rescue => e
      # revert to previous version
      Rake::Task['vlad:custom:rollback'].invoke
      raise e
    end
  end

  namespace :custom do

    desc "Custom rollback to specify deploy target."
    task :rollback, :site do |t, args|
      require_site(args[:site])
      Rake::Task['vlad:custom:rollback_without_restart'].invoke
      Rake::Task['vlad:custom:symlink_config_dir'].invoke
    end

    remote_task :rollback_without_restart do
      if releases.length < 2 then
        abort "could not rollback the code because there is no prior release"
      else
        run "rm -f #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}"
      end
    end

    desc "Custom setup requiring deploy target -- use this instead of vlad:setup"
    task :setup, :site do |t, args|
      require_site(args[:site])

      Rake::Task['vlad:setup'].invoke
      Rake::Task['vlad:custom:share_config_dir'].invoke
      Rake::Task['vlad:set_perms'].invoke
    end

    remote_task :share_config_dir do
      config_dir = File.join(shared_path, "config")
      run "mkdir -p #{config_dir}"
    end

    remote_task :symlink_config_dir do
      run "ln -s #{shared_path}/config #{latest_release}/config"
    end

  end # End custom namespace

end # End vlad namespace
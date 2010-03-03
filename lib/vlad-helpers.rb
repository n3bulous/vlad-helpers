namespace :vlad do

  remote_task :set_perms do
    begin
      run [ "sudo find #{deploy_to} -type f -exec chmod #{file_chmod_to} {} \\;",
            "sudo find #{deploy_to} -type d -exec chmod #{dir_chmod_to} {} \\;",
            "sudo chown -R #{chown_to} #{deploy_to}"].join(" && ")
    rescue => e
      raise e
    end
  end

  task :bundle do
    if (application.size > 0)
      sh [  "rm -rf /tmp/#{release_name}",
            "git clone #{git_connection}:#{application}.git /tmp/#{release_name}",
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

end
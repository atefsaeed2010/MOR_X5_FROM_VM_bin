# -*- encoding : utf-8 -*-
class Audio
  def Audio::convert(src, dst, rm = nil, path = "", filename = "")
    MorLog.my_debug(src)
    MorLog.my_debug(dst)
    #path = Confline.get_value("Temp_Dir")

    convert_cmd = "/usr/local/mor/convert_mp3wav2astwav.sh #{src} #{dst}"
    MorLog.my_debug convert_cmd

    system(convert_cmd)
    MorLog.my_debug("Rm : " + rm.to_s)

    if rm and rm.to_i == 1
      Audio.rm_sound_file(src)
    end

    # send files to remote Asterisk servers if we know file name
    if path.length > 0 and filename.length > 0
      servers = Server.where.not(server_ip: '127.0.0.1').where(active: 1).all

      servers.each do |server|
        servers_ip, server_ssh_port = [server.server_ip, server.ssh_port]
        MorLog.my_debug("moving audio file #{filename} to server #{servers_ip}, path: #{path}")
        # move
        cp_cmd = "/usr/bin/scp -P #{server_ssh_port} #{dst} root@#{servers_ip}:/tmp/#{filename} "
        mv_cmd = "/usr/bin/ssh root@#{servers_ip} -p #{server_ssh_port} -f mv /tmp/#{filename} #{path} "
        MorLog.my_debug(cp_cmd)
        MorLog.my_debug(mv_cmd)

        system(cp_cmd)
        system(mv_cmd)
      end
    end
  end

  def Audio.nice_file_name(string)
    File.basename(string, '.*').gsub('.', '_')
  end

  def Audio.rm_sound_file(src)
    rm_cmd = "rm -fr \'#{src}\'"
    MorLog.my_debug(rm_cmd)
    system(rm_cmd)

    # delete file from remote Asterisk servers
    servers = Server.where.not(server_ip: '127.0.0.1').where(active: 1).all

    servers.each do |server|
      MorLog.my_debug("deleting audio file #{rm_cmd} from server #{servers_ip}")
      rm_cmd = "/usr/bin/ssh root@#{servers_ip} -p #{server_ssh_port} -f #{rm_cmd} "
      MorLog.my_debug(rm_cmd)
      system(rm_cmd)
    end
  end

  def Audio.usible_name(dst, aa)
    if File.exists?(dst)
      aa.to_s + Time.now.to_i.to_s
    else
      aa
    end
  end

  def Audio.create_file(file, object, server_path)
    path, final_path = object.final_path
    unless File.directory?(final_path)
      system("mkdir #{final_path}")
    end

    notice = ''
    if file and notice.blank?
      file_size = file.size.to_i

      if file_size > 0 and notice.blank?
        if file_size < 10485760 and notice.blank?
          filename = File.basename(file.original_filename.gsub(/[^\w\.\_]/, '_'), '_')
          ext = filename.split(".").last
          ext_downcase = ext.downcase

          if ['mp3', 'wav'].include?(ext_downcase) and notice.blank?
            aa = Audio.nice_file_name(filename)
            new_name = Audio.usible_name("#{final_path}/#{aa}.wav", aa)
            #MorLog.my_debug new_name
            src = path + aa + "." + ext_downcase
            File.open(src, "wb") do |file_write|
              file_write.write(file.read)
            end

            dst = "#{final_path}#{final_path.chars.to_a.last == '/' ? '' : '/'}#{new_name}.wav"
            #since we encountered issue that mor tries to create file having '//' in it
            #we should fix that, by doing some hacking. TODO: refactor when some one will
            #assign some time for that. ticket number #6302
            dst = dst.gsub(/[\/]+/, '/')
            src = src.gsub(/[\/]+/, '/')
            new_name = new_name.gsub(/[\/]+/, '/')
            Audio.convert(src, dst, 1, server_path, new_name)
            if !File.exists?(dst) and notice.blank?
              notice = _("File_not_uploaded_please_check_file_system_permissions")
            else
              Action.add_action_hash(User.current, {:action => 'Sound_file_addet', :data => new_name, :data2 => dst, :target_id => object.id, :target_type => object.class.to_s.downcase})
            end
          else
            notice = _("File_is_not_wav_or_mp3")
          end
        else
          notice = _("File_is_too_big")
        end
      else
        notice =_('Please_select_file')
      end
    else
      notice = _("File_not_uploaded")
    end
    return notice, new_name.to_s # + '.wav'
  end

end

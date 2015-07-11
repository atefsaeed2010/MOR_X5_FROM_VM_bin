INSERT INTO `acc_groups`(`id`,`name`                  ,`group_type`) VALUES
                        ( 11 ,'Accountant_permissions','accountant'),
                        ( 12 ,'Reseller_Permissions'  ,'reseller');
UPDATE users set own_providers=1 where id=3;
UPDATE users set acc_group_id=12 where id=3;
Update providers set balance=23.26 where id =1;
INSERT INTO `tariffs` (`id`, `name`, `purpose`, `owner_id`, `currency`) VALUES
(6, 'provider_tariff', 'provider', 3, 'USD');
INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`) VALUES
(2, 'user_provider_1', 'SIP', '', 'user_provider_1', 'please_change', '0.0.0.0', '5060', 1, 1, 1, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 29.26),
(3, 'user_provider_2', 'Zap', '', 'user_provider_2', 'please_change', '0.0.0.0', '4569', 1, 1, 1, 0, 0, '', '', 9, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 29.26),
(4, 'user_provider_3', 'IAX2', '', 'user_provider_3', 'please_change', '0.0.0.0', '4569', 1, 1, 1, 0, 0, '', '', 10, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 29.26),
(5, 'user_provider_4', 'H323', '', 'user_provider_4', 'please_change', '0.0.0.0', '1720', 1, 1, 1, 0, 0, '', '', 11, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 29.26),
(6, 'user_provider_5', 'Skype', '', 'user_provider_5', 'please_change', '0.0.0.0', '4569', 1, 1, 1, 0, 0, '', '', 12, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 0, 0, 29.26),
(7, 'user_reseller_provider_1', 'SIP', '', 'user_reseller_provider_1', 'please_change', '0.0.0.0', '5060', 1, 1, 6, 0, 0, '', '', 13, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 59.26),
(8, 'user_reseller_provider_2', 'Zap', '', 'user_reseller_provider_2', 'please_change', '0.0.0.0', '4569', 1, 1, 6, 0, 0, '', '', 14, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 59.26),
(9, 'user_reseller_provider_3', 'IAX2', '', 'user_reseller_provider_3', 'please_change', '0.0.0.0', '4569', 1, 1, 6, 0, 0, '', '', 15, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 59.26),
(10, 'user_reseller_provider_4', 'H323', '', 'user_reseller_provider_4', 'please_change', '0.0.0.0', '1720', 1, 1, 6, 0, 0, '', '', 16, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 59.26),
(12, 'user_reseller_provider_5', 'Skype', '', 'user_reseller_provider_5', 'please_change', '0.0.0.0', '4569', 1, 1, 6, 0, 0, '', '', 18, 0, 60, 0, 0, 0, 0, NULL, 0, NULL, 0, 0, 3, 0, 59.26);
INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`) VALUES
(8, 'prov_2', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 8, '', '9razd62rgc', 0, 'prov_2', 'SIP', 2, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, 'user_provider_1', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(9, 'prov_3', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 4569, 0, 9, '', '6ffv0w630m', 0, 'prov_3', 'Zap', 2, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, 'user_provider_2', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(10, 'prov_4', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 4569, 0, 10, '', '24cc65z5hw', 0, 'prov_4', 'IAX2', 2, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, 'user_provider_3', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(11, 'prov_5', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 1720, 0, 11, '', 'gurpx74amr', 0, 'prov_5', 'H323', 2, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, 'user_provider_4', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(12, 'prov_6', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 4569, 0, 12, '', 'yk8y279gyf', 0, 'prov_6', 'Skype', 2, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, 'user_provider_5', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(13, 'prov_7', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 13, '', 'xfc4sdz8cx', 0, 'prov_7', 'SIP', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 2, 'user_reseller_provider_1', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(14, 'prov_8', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 4569, 0, 14, '', 'xu69g5u75g', 0, 'prov_8', 'Zap', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 2, 'user_reseller_provider_2', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(15, 'prov_9', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 4569, 0, 15, '', 'tmxkzhfhuf', 0, 'prov_9', 'IAX2', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 2, 'user_reseller_provider_3', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(16, 'prov_10', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 1720, 0, 16, '', '5xz04jamkq', 0, 'prov_10', 'H323', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 2, 'user_reseller_provider_4', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp'),
(18, 'prov_12', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 4569, 0, 18, '', '16j1kdaz4d', 0, 'prov_12', 'Skype', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 2, 'user_reseller_provider_5', 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp');

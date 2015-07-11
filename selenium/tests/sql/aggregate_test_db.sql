INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`, `trunk`, `proxy_port`, `cps_call_limit`, `cps_period`, `timerb`, `callerid_number_pool_id`, `defaultuser`, `useragent`, `type`, `md5secret`, `remotesecret`, `directmedia`, `useclientcode`, `setvar`, `amaflags`, `callcounter`, `busylevel`, `allowoverlap`, `allowsubscribe`, `maxcallbitrate`, `rfc2833compensate`, `session-timers`, `session-expires`, `session-minse`, `session-refresher`, `t38pt_usertpsource`, `regexten`, `defaultip`, `rtptimeout`, `rtpholdtimeout`, `outboundproxy`, `callbackextension`, `timert1`, `qualifyfreq`, `constantssrc`, `contactpermit`, `contactdeny`, `usereqphone`, `textsupport`, `faxdetect`, `buggymwi`, `auth`, `fullname`, `trunkname`, `cid_number`, `callingpres`, `mohinterpret`, `mohsuggest`, `parkinglot`, `hasvoicemail`, `vmexten`, `autoframing`, `rtpkeepalive`, `call-limit`, `g726nonstandard`, `ignoresdpversion`, `allowtransfer`, `dynamic`) VALUES
(8, 'prov8', '192.168.0.8', 'v54cunk71cw4', 'mor', '', 5060, 0, 8, '"cli" <37060011111>', 'nkf2m1yun1', 0, '1005', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', '2000', '', 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', 'no', 'no', 0, 0, 'no', 5060, 0, 0, 6400, 0, '1005', NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(9, '1003', 'dynamic', 'js0funb8k8y6', 'mor_local', '', 5060, 0, 9, '', '1003', 0, '1003', 'SIP', 2, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 0, 'rfc2833', NULL, NULL, '', '', 'no', 'no', '', 'no', 'no', 1, 'Netinkamas', 0, 0, '458769', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', NULL, '', 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp', 'no', '', 0, 0, 'no', 5060, 0, 0, 6400, 0, '1003', NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(10, '40070', 'dynamic', '123123123123', 'mor_local', '192.168.0.187', 5060, 1377189369, 10, '"370600" <370600>', '40070', 0, '40070', 'SIP', 2, 2, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', 'sip:40070@192.168.0.187:5060^3Brinstance=b9ce936f45020a58^3Btransport=UDP', 'no', 0, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 1, 'SIP_device', 0, 0, '987307', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 4, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', 'no', 'no', 0, 0, 'no', 5060, 0, 0, 6400, 0, '40070', 'Zoiper rev.14736', 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(11, '1004', 'dynamic', 'w0u4vqhyt86q', 'mor_local', '', 5060, 0, 11, '', '1004', 0, '1004', 'SIP', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 3, 'rfc2833', NULL, NULL, '', '', 'no', 'no', '', 'no', 'no', 2, 'Nereikalingas_re', 0, 0, '808965', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', NULL, '', 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp', 'no', '', 0, 0, 'no', 5060, 0, 0, 6400, 0, '1004', NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(12, '1010', 'dynamic', '456456456456', 'mor_local', '', 5060, 0, 12, '"40060" <40060>', '1010', 0, '1010', 'SIP', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 3, 'rfc2833', NULL, NULL, NULL, NULL, 'no', 'no', NULL, 'no', 'no', 2, 'SIP_device_re', 0, 0, '537196', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, '', 0, NULL, 0, -1, 0, 0, 0, 0, 0, 0, 'udp', 'no', 'no', 0, 0, 'no', 5060, 0, 0, 6400, 0, '1010', NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(13, 'prov_3', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 5060, 0, 13, '', 'muzfs6dbxu', 0, 'BAD_Provider', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', 'no', 'no', 0, 0, 'no', 5060, 0, 0, 6400, 0, NULL, NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(14, 'prov_4', '0.0.0.0', 'please_change', 'mor', '0.0.0.0', 4569, 0, 14, '', 'gmvtcqcbc9', 0, 'BAD_Provider_2', 'IAX2', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', 'no', 'no', 0, 0, 'no', 4569, 0, 0, 6400, 0, NULL, NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'md5', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

INSERT INTO `devicecodecs` (`id`, `device_id`, `codec_id`, `priority`) VALUES
(15, 8, 1, 0),
(16, 8, 5, 0),
(17, 9, 1, 0),
(18, 9, 5, 0),
(111, 10, 1, 0),
(112, 10, 5, 0),
(113, 11, 1, 0),
(114, 11, 5, 0),
(117, 12, 1, 0),
(118, 12, 5, 0),
(119, 13, 1, 0),
(120, 13, 5, 0),
(121, 14, 1, 0),
(122, 14, 5, 0);

update `dids` set reseller_id=3 where id=1;
update `dids` set status='active' where id=2;
update `dids` set user_id=2 where id=2;
update `dids` set device_id=10 where id=2;

INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`, `balance_limit`, `cps_call_limit`, `cps_period`, `alive`, `periodic_check`, `active`) VALUES
(2, 'SIP_provider', 'SIP', '', '1005', 'v54cunk71cw4', '192.168.0.8', '5060', 1, 1, 1, 0, 0, '', '', 8, 0, 60, 0, 0, 0, 1, '', 1, '', 0, 0, 0, 0, 0.246000000000000, 0.000000000000000, 0, 0, 1, 0, 1),
(3, 'BAD_Provider', 'SIP', '', 'BAD_Provider', 'please_change', '0.0.0.0', '5060', 1, 1, 1, 0, 0, '', '', 13, 0, 60, 0, 0, 0, 0, NULL, 1, NULL, 0, 0, 0, 0, 0.000000000000000, 0.000000000000000, 0, 0, 1, 0, 1),
(4, 'BAD_Provider_2', 'IAX2', '', 'BAD_Provider_2', 'please_change', '0.0.0.0', '4569', 1, 1, 1, 0, 0, '', '', 14, 0, 60, 0, 0, 0, 0, NULL, 1, NULL, 0, 0, 0, 0, 0.000000000000000, 0.000000000000000, 0, 0, 1, 0, 1);

INSERT INTO `lcrs` (`id`, `name`, `order`, `user_id`, `first_provider_percent_limit`, `failover_provider_id`, `no_failover`) VALUES
(2, 'Test_LCR', 'priority', 0, 0.000000000000000, NULL, 0);

INSERT INTO `lcrproviders` (`id`, `lcr_id`, `provider_id`, `active`, `priority`, `percent`) VALUES
(3, 2, 3, 1, 0, 0),
(4, 2, 4, 1, 1, 0),
(6, 2, 1, 1, 2, 0),
(7, 2, 2, 1, 3, 0);

INSERT INTO `lcr_timeperiods` (`id`, `name`, `start_hour`, `end_hour`, `start_minute`, `end_minute`, `start_weekday`, `end_weekday`, `start_day`, `end_day`, `start_month`, `end_month`, `main_lcr_id`, `lcr_id`, `active`) VALUES
(1, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 2, 0, 0),
(2, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 2, 0, 0),
(3, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 2, 0, 0),
(4, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 2, 0, 0),
(5, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 2, 0, 0);

INSERT INTO `locations` (`id`, `name`, `user_id`) VALUES
(2, 'Default location', 3);

INSERT INTO `locationrules` (`id`, `location_id`, `name`, `enabled`, `cut`, `add`, `minlen`, `maxlen`, `lr_type`, `lcr_id`, `tariff_id`, `did_id`, `device_id`) VALUES
(2, 2, 'Int. prefix', 1, '00', '', 10, 20, 'dst', NULL, NULL, NULL, NULL);

INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`) VALUES
(503, 1, 5786, NULL, NULL),
(504, 2, 5786, NULL, NULL),
(505, 3, 0, 448, 0.000000000000000),
(506, 3, 0, 350, 0.000000000000000),
(507, 3, 0, 250, 0.000000000000000),
(508, 3, 0, 456, 0.000000000000000);

INSERT INTO `aratedetails` (`id`, `from`, `duration`, `artype`, `round`, `price`, `rate_id`, `start_time`, `end_time`, `daytype`) VALUES
(237, 1, -1, 'minute', 1, 0.923000000000000, 505, '00:00:00', '23:59:59', ''),
(238, 1, -1, 'minute', 1, 0.900000000000000, 506, '00:00:00', '23:59:59', ''),
(239, 1, -1, 'minute', 1, 0.920000000000000, 507, '00:00:00', '23:59:59', ''),
(240, 1, -1, 'minute', 1, 0.922000000000000, 508, '00:00:00', '23:59:59', '');

update `ratedetails` set rate='0.1' where id=193;
update `ratedetails` set rate='0.5' where id=444;
update `ratedetails` set rate='0.123' where id=491;

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(503, '00:00:00', '23:59:59', 0.120000000000000, 0.000000000000000, 503, 1, 0, ''),
(504, '00:00:00', '23:59:59', 0.520000000000000, 0.000000000000000, 504, 1, 0, '');

INSERT INTO `serverproviders` (`id`, `server_id`, `provider_id`) VALUES
(1, 1, 2),
(2, 1, 3),
(3, 1, 4);

INSERT INTO `server_devices` (`id`, `device_id`, `server_id`) VALUES
(8, 9, 1),
(9, 10, 1),
(10, 11, 1),
(11, 12, 1);

INSERT INTO `didrates` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `increment_s`, `min_time`, `did_id`, `rate_type`, `daytype`) VALUES
(1, '00:00:00', '23:59:59', 0.100000000000000, 0.000000000000000, 1, 0, 1, 'provider', ''),
(2, '00:00:00', '23:59:59', 0.200000000000000, 0.000000000000000, 1, 0, 1, 'incoming', ''),
(3, '00:00:00', '23:59:59', 0.300000000000000, 0.000000000000000, 1, 0, 1, 'owner', ''),
(4, '00:00:00', '23:59:59', 0.400000000000000, 0.000000000000000, 1, 0, 2, 'provider', ''),
(5, '00:00:00', '23:59:59', 0.500000000000000, 0.000000000000000, 1, 0, 2, 'incoming', ''),
(6, '00:00:00', '23:59:59', 0.600000000000000, 0.000000000000000, 1, 0, 2, 'owner', '');

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(2, 0, 0, 0, 0, 'Tax', '', '', '', 'Tax', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);

INSERT INTO `terminators` (`id`, `name`, `user_id`) VALUES
(1, 'Test', 0);

update `users` set tax_id=1 where id=0;
update `users` set lcr_id=2 where id=2;
update `users` set primary_device_id=2 where id=2;
update `users` set lcr_id=2 where id=3;
update `users` set lcr_id=2 where id=5;
update `users` set tariff_id=2 where id=3;
update `users` set tariff_id=3 where id=5;

INSERT INTO `voicemail_boxes` (`uniqueid`, `context`, `mailbox`, `password`, `fullname`, `email`, `pager`, `tz`, `attach`, `saycid`, `dialout`, `callback`, `review`, `operator`, `envelope`, `sayduration`, `saydurationm`, `sendvoicemail`, `delete`, `nextaftercmd`, `forcename`, `forcegreetings`, `hidefromdir`, `stamp`, `device_id`) VALUES
(8, 'default', '1003', '', 'Test User #1', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2013-08-22 18:33:54', 9),
(9, 'default', '40070', '', 'Test User #1', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2013-08-22 18:33:58', 10),
(10, 'default', '1004', '', 'User Resellers', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2013-08-22 18:35:00', 11),
(11, 'default', '1010', '', 'User Resellers', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2013-08-22 18:35:03', 12);

INSERT INTO `calls` 
(`id`, `calldate`, `clid`, `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`, `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`, `dst_user_id`) VALUES
(52, '2013-08-22 18:54:17', '"370600" <370600>', '370600', '37060064753', '', '', '', '', '', 1, 0, 'FAILED', 0, '0', '1377186857.28', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 200, 'Local', 0, 0, '37060064753', 0, 0, '', '', 0.016027, 0, 0, 0),
(53, '2013-08-22 18:54:17', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-00000016', '', '', '', 1377186816, 0, 'FAILED', 0, '10', '1377186857.26', '', 10, 0, 0, 0, 0, 3, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 21, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '0.0.0.0', 1377186857.203, 0, 0, 0),
(54, '2013-08-22 18:54:17', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-00000016', '', '', '', 1377186816, 0, 'FAILED', 0, '10', '1377186857.26', '', 10, 0, 0, 0, 0, 4, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 20, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '0.0.0.0', 1377186857.217, 0, 0, 0),
(55, '2013-08-22 18:54:17', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-00000016', '', '', '', 1377186816, 0, 'FAILED', 0, '10', '1377186857.26', '', 10, 0, 0, 0, 0, 1, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 0, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '22.33.44.55', 1377186861.221, 0, 0, 0),
(56, '2013-08-22 18:54:17', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-00000016', '', '', '', 1377186944, 15, 'ANSWERED', 0, '10', '1377186857.26', '', 10, 0, 0, 0, 0, 2, 0.12, 15, 0.03, 2, 0.52, 15, 0.13, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 16, 'Local', 0, 0, '37060064753', 0, 0, '192.168.0.187', '192.168.0.8', 1377186882.532, 14.626, 15, 0),
(57, '2013-08-22 19:06:12', '"370600" <370600>', '370600', '37060064753', '', '', '', '', '', 1, 0, 'FAILED', 0, '0', '1377187572.33', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 200, 'Local', 0, 0, '37060064753', 0, 0, '', '', 0.008152, 0, 0, 0),
(58, '2013-08-22 19:06:12', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001a', '', '', '', 1377187584, 0, 'FAILED', 0, '10', '1377187572.31', '', 10, 0, 0, 0, 0, 3, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 21, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '0.0.0.0', 1377187572.997, 0, 0, 0),
(59, '2013-08-22 19:06:12', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001a', '', '', '', 1377187584, 0, 'FAILED', 0, '10', '1377187572.31', '', 10, 0, 0, 0, 0, 4, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 20, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '0.0.0.0', 1377187573.011, 0, 0, 0),
(60, '2013-08-22 19:06:12', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001a', '', '', '', 1377187584, 0, 'FAILED', 0, '10', '1377187572.31', '', 10, 0, 0, 0, 0, 1, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 0, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '22.33.44.55', 1377187577.024, 0, 0, 0),
(61, '2013-08-22 19:06:12', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001a', '', '', '', 1377187584, 4, 'ANSWERED', 0, '10', '1377187572.31', '', 10, 0, 0, 0, 0, 2, 0.12, 4, 0.008, 2, 0.52, 4, 0.034667, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 16, 'Local', 0, 0, '37060064753', 0, 0, '192.168.0.187', '192.168.0.8', 1377187588.016, 3.381, 4, 0),
(62, '2013-08-22 19:06:31', '"370600" <370600>', '370600', '37060064753', '', '', '', '', '', 1, 0, 'FAILED', 0, '0', '1377187591.38', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '', 1, 200, 'Local', 0, 0, '37060064753', 0, 0, '', '', 0.014798, 0, 0, 0),
(63, '2013-08-22 19:06:31', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001e', '', '', '', 1377187584, 0, 'FAILED', 0, '10', '1377187591.36', '', 10, 0, 0, 0, 0, 3, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 21, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '0.0.0.0', 1377187591.96, 0, 0, 0),
(64, '2013-08-22 19:06:31', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001e', '', '', '', 1377187584, 0, 'FAILED', 0, '10', '1377187591.36', '', 10, 0, 0, 0, 0, 4, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 20, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '0.0.0.0', 1377187591.973, 0, 0, 0),
(65, '2013-08-22 19:06:31', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001e', '', '', '', 1377187584, 0, 'FAILED', 0, '10', '1377187591.36', '', 10, 0, 0, 0, 0, 1, NULL, NULL, NULL, 2, NULL, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '3706', 1, 0, 'Local', 0, 0, '37060064753', 0, NULL, '192.168.0.187', '22.33.44.55', 1377187595.988, 0, 0, 0),
(66, '2013-08-22 19:06:31', '"370600" <370600>', '370600', '37060064753', '', 'SIP/40070-0000001e', '', '', '', 1377187712, 0, 'NO ANSWER', 0, '10', '1377187591.36', '', 10, 0, 0, 0, 0, 2, 0.12, 0, 0, 2, 0.52, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, '3706', 1, 241, 'Local', 0, 0, '37060064753', 0, 0, '192.168.0.187', '192.168.0.8', 1377187656.067, 0, 0, 0);

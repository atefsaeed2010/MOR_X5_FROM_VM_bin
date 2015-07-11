INSERT INTO `servers` (`id`, `server_ip`, `stats_url`, `server_type`, `active`, `comment`, `hostname`, `maxcalllimit`,  `ami_port`, `ami_secret`, `ami_username`, `port`, `ssh_username`, `ssh_secret`, `ssh_port`, `gateway_active`, `version`, `uptime`) VALUES
(20, '127.0.0.2', NULL, 'asterisk', 1, 'second serv', '127.0.0.2', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', ''),
(30, '127.0.0.3', NULL, 'asterisk', 1, 'third serv', '127.0.0.3', 1000, '5038', 'morsecret', 'mor', 5060, 'root', NULL, 22, 0, '', '');

INSERT INTO `devicecodecs` (`id`, `device_id`, `codec_id`, `priority`) VALUES
(30, 20, 1, 0),
(31, 20, 5, 0),
(32, 30, 1, 0),
(33, 30, 5, 0);

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`) VALUES
(20, 'mor_server_20', '127.0.0.2', '', 'mor_direct', '127.0.0.2', 5060, 0, 20, '', 'mor_server_20', 0, 'mor_server_20', 'SIP', 0, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, 'mor_server_20'),
(30, 'mor_server_30', '127.0.0.3', '', 'mor_direct', '127.0.0.3', 5060, 0, 30, '', 'mor_server_30', 0, 'mor_server_30', 'SIP', 0, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, 'mor_server_30');

INSERT INTO `voicemail_boxes` (`uniqueid`, `context`, `mailbox`, `password`, `fullname`, `email`, `pager`, `tz`, `attach`, `saycid`, `dialout`, `callback`, `review`, `operator`, `envelope`, `sayduration`, `saydurationm`, `sendvoicemail`, `delete`, `nextaftercmd`, `forcename`, `forcegreetings`, `hidefromdir`, `stamp`, `device_id`) VALUES
(8, 'default', 'mor_server_20', '', 'System Admin', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2014-12-13 17:19:47', 20),
(9, 'default', 'mor_server_30', '', 'System Admin', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2014-12-13 17:20:16', 30);


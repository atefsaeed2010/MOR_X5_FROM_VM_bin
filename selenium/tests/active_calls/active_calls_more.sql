INSERT INTO `activecalls` 
 (`id`, `server_id`, `uniqueid`,         `start_time`                        , `answer_time`                     ,`transfer_time`, `src`,       `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
 (100,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 10 SECOND),DATE_SUB(NOW(), INTERVAL 5 SECOND),           NULL,'37060011221','123123'     ,5,              0,             'SIP/10.219.62.200-c40daf10'   ,'',           '1231',     1,              11,        0,          0,          '37060011230'),
 (110,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 50 SECOND),DATE_SUB(NOW(), INTERVAL 40 SECOND),           NULL,'37060011225','37060011242',4,              9,             'SIP/10.219.62.200-c40daf10'   ,'',           '370' ,     1,              15,        2,          0,          '37060011242'),
 (102,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 90 SECOND),DATE_SUB(NOW(), INTERVAL 70 SECOND),           NULL,'37060011238','37060011226',9,              4,             'SIP/10.219.62.200-c40daf10'   ,'',           '370' ,     1,              28,        4,          0,          '37060011226'),
 (103,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 130 SECOND),DATE_SUB(NOW(), INTERVAL 100 SECOND),           NULL,'37060011234','123123'     ,7,              0,             'SIP/10.219.62.200-c40daf10'   ,'',           '1231',     11,              24,        5,          3,          '37060011239'),
 (140,    1,           '1249298495.111727',DATE_SUB(NOW(), INTERVAL 170 SECOND),DATE_SUB(NOW(), INTERVAL 140 SECOND),           NULL,'37060011233','37060011223',8,              5,             'SIP/10.219.62.200-c40daf10'   ,'',           '370' ,     12,              23,        5,          3,          '37060011223');

INSERT INTO `activecalls` 
 (`id`, `server_id`, `uniqueid`,         `start_time`        , `answer_time`, `transfer_time`        , `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                    `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
 (5,    1,           '1249298495.111727',NOW()+3              ,      NOW(),          NULL,            '306984327347','63727007887',7,              0,               'SIP/10.219.62.200-c40daf10',  '63',     2,              1,       5,         3,          '63727007887'),
 (11,    2,           '1249298495.111727','2010-15-50 03:30:11',      NOW()+2,          NULL,            '306984327347','63727007887',7,              0,               'SIP/10.219.62.200-c40daf10',NULL,     2,              1,       5,         3,          '63727007886');

INSERT INTO `activecalls`
  (`id`, `server_id`, `uniqueid`,         `start_time`, `answer_time`, `transfer_time`, `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
  (24  ,    1,      '1249296551.111096',   NOW(),        NOW(),          NULL,        '555333327342','55533307889', 11,              0,               'SIP/10.219.62.200-c40daf10','',           '555333',     1,              0,       9,         0,          '55533307889');
  

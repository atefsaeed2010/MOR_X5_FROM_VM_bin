/* one cs_invoice and one outgoing active call for cs_user 1 */

INSERT INTO `activecalls`
  (`id`, `server_id`, `uniqueid`,         `start_time`, `answer_time`, `transfer_time`, `src`,         `dst`,       `src_device_id`, `dst_device_id`, `channel`,                   `dstchannel`, `prefix`, `provider_id`, `did_id`, `user_id`, `owner_id`, `localized_dst`) VALUES
  (24,    1,           '1249296551.111096',NOW(),        NOW(),          NULL,            '306984327342','63727007889', 11,              0,               'SIP/10.219.62.200-c40daf10','',           '63',     1,              0,       9,         0,          '63727007889');

INSERT INTO `cs_invoices` (`id`, `callshop_id`, `user_id`, `state`, `invoice_type`, `balance`, `comment`, `paid_at`, `updated_at`, `created_at`) VALUES (1, 2, 7, 'unpaid', 'prepaid', 5.00, 'komentaras', NULL, DATE_SUB(NOW() , INTERVAL 1 HOUR), DATE_SUB(NOW(), INTERVAL 1 HOUR));

/* call records for stats */
INSERT INTO `calls` (`id`, `calldate`          , `clid`               , `src`       , `dst`       , `channel`, `duration`, `billsec`, `disposition`, `accountcode`, `uniqueid`   , `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`)
VALUES (111  ,DATE_SUB(NOW(), INTERVAL 30 SECOND),''                    ,'101'        ,'123123'     ,''         ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113379.3',2               ,0               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,7         ,1           ,1              ,5            ,3             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0);

/* current */

INSERT INTO `calls` (`id`, `calldate`          , `clid`               , `src`       , `dst`       , `channel`, `duration`, `billsec`, `disposition`, `accountcode`, `uniqueid`   , `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`)
VALUES (104  ,DATE_SUB(NOW(), INTERVAL 30 SECOND),''                    ,'101'        ,'123123'     ,''         ,40         ,50        ,'ANSWERED'    ,'2'           ,'1232113379.3',2               ,0               ,0           ,0           ,0         ,1             ,0               ,0                  ,1                ,7         ,1           ,1              ,5            ,3             ,0               ,0                  ,4                ,0            ,0              ,0                 ,0               ,'1231'   ,1           ,16            ,'Local'      ,0               ,0                ,'123123'        ,0                 ,0        ,''              ,''              ,0               ,0              ,0);

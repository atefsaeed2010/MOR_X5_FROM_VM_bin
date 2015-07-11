INSERT INTO `users` (`id`, `username`, `password`, `usertype`, `logged`, `first_name`, `last_name`, `calltime_normative`, `show_in_realtime_stats`, `balance`, `frozen_balance`, `lcr_id`, `postpaid`, `blocked`, `tariff_id`, `month_plan_perc`, `month_plan_updated`, `sales_this_month`, `sales_this_month_planned`, `show_billing_info`, `primary_device_id`, `credit`, `clientid`, `agreement_number`, `agreement_date`, `language`, `taxation_country`, `vat_number`, `vat_percent`, `address_id`, `accounting_number`, `owner_id`, `hidden`, `allow_loss_calls`, `vouchers_disabled_till`, `uniquehash`, `temporary_id`, `send_invoice_types`, `call_limit`, `sms_tariff_id`, `sms_lcr_id`, `sms_service_active`, `cyberplat_active`, `call_center_agent`, `generate_invoice`, `tax_1`, `tax_2`, `tax_3`, `tax_4`, `block_at`, `block_at_conditional`, `block_conditional_use`, `recording_enabled`, `recording_forced_enabled`, `recordings_email`, `recording_hdd_quota`, `warning_email_active`, `warning_email_balance`, `warning_email_sent`, `tax_id`, `invoice_zero_calls`, `acc_group_id`) VALUES 
(21,'1011','dbc0f004854457f59fb16ab863a3a1722cef553f','user',0,'Test User SU','#2',3,1,0,0,1,1,0,2,0,'2000-01-01 00:00:00',0,0,1,0,-1,NULL,NULL,NULL,NULL,NULL,NULL,18,NULL,NULL,0,0,0,'2000-01-01 00:00:00',NULL,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,0,1,0),
(22,'1012','dbc0f004854457f59fb16ab863a3a1722cef553f','user',0,'Test User BE','#3',3,1,0,0,1,1,0,2,0,'2000-01-01 00:00:00',0,0,1,0,-1,NULL,NULL,NULL,NULL,NULL,NULL,18,NULL,NULL,0,0,0,'2000-01-01 00:00:00',NULL,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,0,1,0),
(23,'1013','dbc0f004854457f59fb16ab863a3a1722cef553f','user',0,'Test User SU','#4',3,1,0,0,1,1,0,2,0,'2000-01-01 00:00:00',0,0,1,0,-1,NULL,NULL,NULL,NULL,NULL,NULL,18,NULL,NULL,0,0,0,'2000-01-01 00:00:00',NULL,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,0,1,0),
(31,'reseller1','b5e13d82f19a015d638e3368a8e9cc1bf6d4a69a','reseller',0,'Test BE','Reseller2',3,0,0,0,1,1,0,4,0,NULL,0,0,1,0,-1,'','0000000001','2009-03-31','',123,'',19,2,'',0,0,0,'2000-01-01 00:00:00','qg2audn8qa',NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,1,1,0),
(32,'reseller2','b5e13d82f19a015d638e3368a8e9cc1bf6d4a69a','reseller',0,'Test SU','Reseller3',3,0,0,0,1,1,0,4,0,NULL,0,0,1,0,-1,'','0000000001','2009-03-31','',123,'',19,2,'',0,0,0,'2000-01-01 00:00:00','qg2audn8qa',NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,1,1,0),
(33,'reseller3','b5e13d82f19a015d638e3368a8e9cc1bf6d4a69a','reseller',0,'Test BE','Reseller4',3,0,0,0,1,1,0,4,0,NULL,0,0,1,0,-1,'','0000000001','2009-03-31','',123,'',19,2,'',0,0,0,'2000-01-01 00:00:00','qg2audn8qa',NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,1,1,0),
(41,'accountant1','4cd5edcd9aa8e3aed333a5dccda30a3b4a7eeeb7','accountant',0,'TestSU','Accountant2',3,0,0,0,1,1,0,2,0,NULL,0,0,1,0,-1,'','0000000002','2009-03-31','',123,'',0,3,'',0,0,0,'2000-01-01 00:00:00',NULL,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,2,1,0),
(42,'accountant2','4cd5edcd9aa8e3aed333a5dccda30a3b4a7eeeb7','accountant',0,'TestBE','Accountant3',3,0,0,0,1,1,0,2,0,NULL,0,0,1,0,-1,'','0000000002','2009-03-31','',123,'',0,3,'',0,0,0,'2000-01-01 00:00:00',NULL,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,2,1,0),
(43,'accountant3','4cd5edcd9aa8e3aed333a5dccda30a3b4a7eeeb7','accountant',0,'TestSU','Accountant4',3,0,0,0,1,1,0,2,0,NULL,0,0,1,0,-1,'','0000000002','2009-03-31','',123,'',0,3,'',0,0,0,'2000-01-01 00:00:00',NULL,NULL,1,0,NULL,NULL,0,0,0,1,0,0,0,0,'2008-01-01',15,0,0,0,NULL,100,0,0,0,2,1,0),
(51,'user_reseller1','09ded230f7c143810e7dbd890d7cf0fa46cb2fe8','user',0,'UserBE','Resellers2',3,0,0,0,1,1,0,3,0,NULL,0,0,1,0,-1,'','0000000003','2009-03-31','',1,'',19,4,'',3,0,0,'2000-01-01 00:00:00',NULL,NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,3,1,0),
(52,'user_reseller2','09ded230f7c143810e7dbd890d7cf0fa46cb2fe8','user',0,'UserSU','Resellers3',3,0,0,0,1,1,0,3,0,NULL,0,0,1,0,-1,'','0000000003','2009-03-31','',1,'',19,4,'',3,0,0,'2000-01-01 00:00:00',NULL,NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,3,1,0),
(53,'user_reseller3','09ded230f7c143810e7dbd890d7cf0fa46cb2fe8','user',0,'UserBE','Resellers4',3,0,0,0,1,1,0,3,0,NULL,0,0,1,0,-1,'','0000000003','2009-03-31','',1,'',19,4,'',3,0,0,'2000-01-01 00:00:00',NULL,NULL,0,0,NULL,NULL,0,0,0,1,0,0,0,0,'2009-01-01',15,0,0,0,NULL,100,0,0,0,3,1,0);

INSERT INTO `subscriptions` (`id`, `service_id`, `user_id`, `device_id`, `activation_start`, `activation_end`, `added`, `memo`) 
VALUES                      (12,1,21,NULL,'2009-05-22 09:25:00','2014-07-22 09:25:00','2009-04-22 09:25:00','Test_preriodic_service_memo'),
                            (13,1,23,NULL,'2009-06-22 09:25:00','2014-07-22 09:25:00','2009-04-22 09:25:00','Test_preriodic_service_memo'),
                            (14,1,32,NULL,'2009-03-22 09:25:00','2014-07-22 09:25:00','2009-04-22 09:25:00','Test_preriodic_service_memo'),
                            (15,1,41,NULL,'2009-07-22 09:25:00','2014-07-22 09:25:00','2009-04-22 09:25:00','Test_preriodic_service_memo'),
                            (16,1,43,NULL,'2009-01-22 09:25:00','2014-07-22 09:25:00','2009-04-22 09:25:00','Test_preriodic_service_memo'),
                            (17,1,52,NULL,'2009-06-22 09:25:00','2014-07-22 09:25:00','2009-04-22 09:25:00','Test_preriodic_service_memo');

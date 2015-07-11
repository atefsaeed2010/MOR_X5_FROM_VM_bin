#sukuriamas paprasciausias queue testavimui, ateity galima bus tikslinti duomenis. 

INSERT INTO `queues` (`id`, `name`, `extension`, `server_id`, `strategy`, `weight`, `autofill`, `ringinuse`, `failover_action`, `failover_data`, `cid_name_prefix`, `reportholdtime`, `announce`, `memberdelay`, `timeout`, `retry`, `wrapuptime`, `allow_callee_hangup`, `maxlen`, `join_announcement`, `ringing_instead_of_moh`, `moh_id`, `ring_at_once`, `joinempty`, `leavewhenempty`, `allow_caller_hangup`, `context`, `max_wait_time`, `announce_frequency`, `min_announce_frequency`, `announce_position`, `announce_position_limit`, `announce_holdtime`, `announce_round_seconds`, `periodic_announce_frequency`, `random_periodic_announce`, `relative_periodic_announce`, `servicelevel`, `penaltymemberslimit`, `autopause`, `setinterface`, `setqueueentryvar`, `setqueuevar`, `membermacro`, `membergosub`, `monitor_format`, `monitor_type`, `eventwhencalled`, `eventmemberstatus`, `timeoutrestart`, `queue_youarenext`, `queue_thereare`, `queue_callswaiting`, `queue_holdtime`, `queue_minutes`, `queue_seconds`, `queue_thankyou`, `queue_lessthan`, `queue_reporthold`, `timeoutpriority`) VALUES
(7001, 'test queue', '123', 1, 'ringall', 0, 'yes', 'no', 'hangup', NULL, NULL, 'no', 0, 0, 30, 5, 0, 'no', 0, 0, 'no', 0, 'no', 'penalty,paused,invalid', 'penalty,paused,invalid', 'no', 0, 300, 90, 15, 'yes', 5, 'once', 0, 60, 'no', 'no', 0, 0, 'yes', 'no', 'no', 'no', NULL, NULL, NULL, 'MixMonitor', 'no', 'no', 'no', 0, 0, 0, 0, 0, 0, 0, 0, 0, 'app');

INSERT INTO `dialplans` (`id`, `name`, `dptype`, `data1`, `data2`, `data3`, `data4`, `data5`, `data6`, `data7`, `data8`, `sound_file_id`, `user_id`, `data9`, `data10`, `data11`, `data12`) VALUES
(7001, 'test queue', 'queue', '7001', '123', NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, NULL);

INSERT INTO `extlines` (`id`, `context`, `exten`, `priority`, `app`, `appdata`, `device_id`) VALUES
(7001, 'mor_local', '123', 1, 'Set', 'MOR_DP_ID=7001', 0),
(7002, 'mor_local', '123', 2, 'Goto', 'mor_queues,queue7001, 1', 0);

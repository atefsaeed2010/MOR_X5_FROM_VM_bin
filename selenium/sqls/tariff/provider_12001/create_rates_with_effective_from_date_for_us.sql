INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`) VALUES
(120147, 12001, 9241, NULL, NULL, '2013-01-01 00:00:00'),
(120151, 12001, 9245, NULL, NULL, '2013-01-01 00:00:00'),
(120152, 12001, 9246, NULL, NULL, '2013-01-01 00:00:00'),
(120153, 12001, 9247, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120154, 12001, 9248, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120155, 12001, 9249, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120156, 12001, 9250, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120157, 12001, 9251, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120158, 12001, 9252, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120159, 12001, 9253, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120160, 12001, 9254, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120161, 12001, 9255, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120162, 12001, 9256, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120163, 12001, 9257, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120164, 12001, 9258, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120165, 12001, 19798, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120166, 12001, 19799, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120167, 12001, 19800, NULL, 10.000000000000000, '2013-01-01 00:00:00'),
(120168, 12001, 20051, NULL, 20.000000000000000, '2013-01-01 00:00:00'),
(120169, 12001, 20052, NULL, 20.000000000000000, '2013-01-01 00:00:00'),
(120170, 12001, 20053, NULL, 20.000000000000000, '2013-01-01 00:00:00'),
(120171, 12001, 20054, NULL, 20.000000000000000, '2013-01-01 00:00:00'),
(120172, 12001, 20055, NULL, 20.000000000000000, '2013-01-01 00:00:00'),
(120177, 12001, 20060, NULL, 20.000000000000000, '2013-01-01 00:00:00'),
(120178, 12001, 20061, NULL, 20.000000000000000, '2013-01-01 00:00:00'),
(120179, 12001, 20062, NULL, 20.000000000000000, '2013-01-01 00:00:00');

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(120147, '00:00:00', '23:59:59', 0.259500000000000, 0.000000000000000, 120147, 1, 0, ''),
(120151, '00:00:00', '23:59:59', 0.645960000000000, 0.000000000000000, 120151, 1, 0, ''),
(120152, '00:00:00', '23:59:59', 0.695000000000000, 0.000000000000000, 120152, 1, 0, ''),
(120153, '00:00:00', '23:59:59', 0.158900000000000, 0.000000000000000, 120153, 1, 0, ''),
(120154, '00:00:00', '23:59:59', 0.025900000000000, 0.000000000000000, 120154, 1, 0, ''),
(120155, '00:00:00', '23:59:59', 0.059500000000000, 0.000000000000000, 120155, 1, 0, ''),
(120156, '00:00:00', '23:59:59', 0.696500000000000, 0.000000000000000, 120156, 1, 0, ''),
(120157, '00:00:00', '23:59:59', 0.694700000000000, 0.000000000000000, 120157, 1, 0, ''),
(120158, '00:00:00', '23:59:59', 0.695800000000000, 0.000000000000000, 120158, 1, 0, ''),
(120159, '00:00:00', '23:59:59', 0.269800000000000, 0.000000000000000, 120159, 1, 0, ''),
(120160, '00:00:00', '23:59:59', 0.148200000000000, 0.000000000000000, 120160, 1, 0, ''),
(120161, '00:00:00', '23:59:59', 0.691500000000000, 0.000000000000000, 120161, 1, 0, ''),
(120162, '00:00:00', '23:59:59', 0.047600000000000, 0.000000000000000, 120162, 1, 0, ''),
(120163, '00:00:00', '23:59:59', 0.269900000000000, 0.000000000000000, 120163, 1, 0, ''),
(120164, '00:00:00', '23:59:59', 0.029900000000000, 0.000000000000000, 120164, 1, 0, ''),
(120165, '00:00:00', '23:59:59', 0.952200000000000, 0.000000000000000, 120165, 1, 0, ''),
(120166, '00:00:00', '23:59:59', 0.069900000000000, 0.000000000000000, 120166, 1, 0, ''),
(120167, '00:00:00', '23:59:59', 0.295200000000000, 0.000000000000000, 120167, 1, 0, ''),
(120168, '00:00:00', '23:59:59', 0.333000000000000, 0.440000000000000, 120168, 0, 2, ''),
(120169, '00:00:00', '23:59:59', 1.004000000000000, 0.445000000000000, 120169, 0, 3, ''),
(120170, '00:00:00', '23:59:59', 0.484000000000000, 0.770000000000000, 120170, 0, 4, ''),
(120171, '00:00:00', '23:59:59', 0.554000000000000, 0.830000000000000, 120171, 0, 5, ''),
(120172, '00:00:00', '23:59:59', 0.764000000000000, 0.540000000000000, 120172, 1, 2, ''),
(120177, '00:00:00', '23:59:59', 0.640000000000000, 0.423400000000000, 120177, 0, 1, ''),
(120178, '00:00:00', '23:59:59', 0.404000000000000, 0.423000000000000, 120178, 0, 2, ''),
(120179, '00:00:00', '23:59:59', 0.001000000000000, 0.423000000000000, 120179, 0, 4, '');

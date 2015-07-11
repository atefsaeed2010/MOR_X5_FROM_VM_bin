#grupe be pinigu
INSERT INTO `cardgroups` (`id`, `name`, `description`, `price`, `setup_fee`, `ghost_min_perc`, `daily_charge`, `tariff_id`, `lcr_id`, `created_at`, `valid_from`, `valid_till`, `vat_percent`, `number_length`, `pin_length`, `dialplan_id`, `image`, `location_id`, `owner_id`, `tax_id`, `valid_after_first_use`, `ghost_balance_perc`, `use_external_function`, `allow_loss_calls`, `tell_cents`, `tell_balance_in_currency`, `solo_pinless`, `disable_voucher`, `hidden`, `callerid_leave`) VALUES
(14301, 'reseller cc group', 'card group description', 0.000000000000000, 0.000000000000000, 100.000000000000000, 0.000000000000000, 3, 1, '2013-10-28 10:40:55', '2013-10-28 00:00:00', '2017-12-31 23:59:59', 0.000000000000000, 10, 6, 0, 'example.jpg', 2, 3, 14301, 0, 100.000000000000000, 0, 0, 0, 'USD', 0, 0, 0, 0);

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(14301, 0, 0, 0, 0, 'Tax', '', '', '', 'Tax', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);

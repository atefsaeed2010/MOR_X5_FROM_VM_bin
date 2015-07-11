INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(14, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax_name', 50.000000000000000, 40.000000000000000, 30.000000000000000, 10.000000000000000, 1);

UPDATE `mor`.`users` SET `tax_id` = '14' WHERE `users`.`id` =0 LIMIT 1 ;
UPDATE `mor`.`users` SET `tax_id` = '14' WHERE `users`.`id` =2 LIMIT 1 ;
UPDATE `mor`.`users` SET `tax_id` = '14' WHERE `users`.`id` =3 LIMIT 1 ;
UPDATE `mor`.`users` SET `tax_id` = '14' WHERE `users`.`id` =4 LIMIT 1 ;


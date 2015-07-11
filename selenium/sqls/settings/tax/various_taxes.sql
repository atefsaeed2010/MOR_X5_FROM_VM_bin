DELETE from `conflines` where name='Tax_1_Value';
DELETE from `conflines` where name='Tax_1';
DELETE from `conflines` where name='Tax_2';
DELETE from `conflines` where name='Tax_3';
DELETE from `conflines` where name='Tax_4';
DELETE from `conflines` where name='Total_tax_name';
DELETE from `conflines` where name='Banned_CLIs_default_IVR_id';
DELETE from `conflines` where name='Tax_2_Value';
DELETE from `conflines` where name='Tax_3_Value';
DELETE from `conflines` where name='Tax_4_Value';
DELETE from `conflines` where name='Prepaid_Invoice_Number_Length';
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(184, 'Tax_1', 'VAT', 1, '1'),
(185, 'Tax_2', 'Second-tax', 0, '1'),
(186, 'Tax_3', 'Third-tax', 0, '1'),
(187, 'Tax_4', 'Fourth-tax', 0, '1'),
(188, 'Total_tax_name', 'Total_tax_name', 0, NULL),
(189, 'Banned_CLIs_default_IVR_id', '0', 0, NULL),
(190, 'Tax_1_Value', '10.0', 0, NULL),
(191, 'Tax_2_Value', '10.0', 0, NULL),
(192, 'Tax_3_Value', '20.0', 0, NULL),
(193, 'Tax_4_Value', '30.0', 0, NULL),
(206, 'Prepaid_Invoice_Number_Length', '5', 0, NULL),
(240, 'Tax_1', 'First-tax', 0, '1');

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(2, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(3, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(4, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(5, 0, 1, 1, 1, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax_name', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1);


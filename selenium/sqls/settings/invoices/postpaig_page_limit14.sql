delete from conflines where name='Prepaid_Invoice_Number_Length';

INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(206, 'Prepaid_Invoice_Number_Length', '5', 0, NULL);

delete from conflines where name='Invoice_page_limit';

INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(271, 'Invoice_page_limit', '14', 0, NULL);


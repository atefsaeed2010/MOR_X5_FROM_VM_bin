delete from conflines where name='Prepaid_Invoice_Number_Length';
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(206, 'Prepaid_Invoice_Number_Length', '5', 0, NULL);
delete from conflines where name='Prepaid_Invoice_Number_Type';
insert into conflines (id, name, value, owner_id, value2) values (207, 'Prepaid_Invoice_Number_Type', '1', 0, NULL);


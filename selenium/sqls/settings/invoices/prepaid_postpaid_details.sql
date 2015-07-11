delete from conflines where name='Invoice_Add_Average_rate';
delete from conflines where name='Invoice_Show_Time_in_Minutes';
delete from conflines where name='Prepaid_Invoice_Add_Average_rate';
delete from conflines where name='Prepaid_Invoice_Show_Time_in_Minutes';
INSERT INTO `conflines` (`id`, `name`, `value`, `owner_id`, `value2`) VALUES
(150015, 'Invoice_Add_Average_rate', '1', 0, NULL),
(150016, 'Invoice_Show_Time_in_Minutes', '1', 0, NULL),
(150020, 'Prepaid_Invoice_Add_Average_rate', '1', 0, NULL),
(150021, 'Prepaid_Invoice_Show_Time_in_Minutes', '1', 0, NULL);



SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

CREATE DATABASE IF NOT EXISTS `blood_bank` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `blood_bank`;

CREATE TABLE `donation` (
  `p_id` int(10) NOT NULL,
  `d_date` date NOT NULL,
  `d_time` time NOT NULL,
  `d_quantity` int(1) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `person` (
  `p_id` int(10) NOT NULL,
  `p_name` varchar(25) NOT NULL,
  `p_phone` char(10) NOT NULL,
  `p_dob` date NOT NULL,
  `p_address` varchar(100) DEFAULT NULL,
  `p_gender` char(1) NOT NULL,
  `p_blood_group` varchar(3) NOT NULL,
  `p_med_issues` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `receive` (
  `p_id` int(10) NOT NULL,
  `r_date` date NOT NULL,
  `r_time` time NOT NULL,
  `r_quantity` int(1) NOT NULL,
  `r_hospital` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `stock` (
  `s_blood_group` varchar(3) NOT NULL,
  `s_quantity` int(5) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `stock` (`s_blood_group`, `s_quantity`) VALUES
('A+', 0),
('A-', 0),
('AB+', 0),
('AB-', 0),
('B+', 0),
('B-', 0),
('O+', 0),
('O-', 0);

CREATE TABLE `user` (
  `username` varchar(10) NOT NULL,
  `password` varchar(16) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `user` (`username`, `password`) VALUES
('SuperAdmin', '12345678'),
('test_user', 'qwertyuiop');

ALTER TABLE `donation`
  ADD PRIMARY KEY (`p_id`,`d_date`,`d_time`);
ALTER TABLE `person`
  ADD PRIMARY KEY (`p_id`);
ALTER TABLE `receive`
  ADD PRIMARY KEY (`p_id`,`r_date`,`r_time`);
ALTER TABLE `stock`
  ADD PRIMARY KEY (`s_blood_group`);
ALTER TABLE `user`
  ADD PRIMARY KEY (`username`);
ALTER TABLE `person`
  MODIFY `p_id` int(10) NOT NULL AUTO_INCREMENT;
ALTER TABLE `donation`
  ADD CONSTRAINT `Donation_ibfk_1` FOREIGN KEY (`p_id`) REFERENCES `person` (`p_id`);
ALTER TABLE `receive`
  ADD CONSTRAINT `Receive_ibfk_1` FOREIGN KEY (`p_id`) REFERENCES `person` (`p_id`);

DELIMITER //

CREATE TRIGGER `check_stock_before_insert` BEFORE INSERT ON `donation`
FOR EACH ROW
BEGIN
  DECLARE stock_quantity INT;

  -- Fetch the blood group from the associated person
  SELECT `p_blood_group` INTO @blood_group
  FROM `person`
  WHERE `p_id` = NEW.p_id;

  -- Fetch the stock quantity for the blood group
  SELECT `s_quantity` INTO stock_quantity
  FROM `stock`
  WHERE `s_blood_group` = @blood_group;

  IF NEW.d_quantity + stock_quantity > 15 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'The donation quantity exceeds the maximum stock limit for this blood group.';
  END IF;
END;

//
CREATE TRIGGER `update_stock_donation` AFTER INSERT ON `donation`
FOR EACH ROW
BEGIN
  UPDATE `stock`
  SET `s_quantity` = `s_quantity` + NEW.d_quantity
  WHERE `s_blood_group` = (SELECT `p_blood_group` FROM `person` WHERE `p_id` = NEW.p_id);
END;

//

CREATE TRIGGER `update_stock_receive` AFTER INSERT ON `receive`
FOR EACH ROW
BEGIN
  UPDATE `stock`
  SET `s_quantity` = `s_quantity` - NEW.r_quantity
  WHERE `s_blood_group` = (SELECT `p_blood_group` FROM `person` WHERE `p_id` = NEW.p_id);
END;

//
CREATE TRIGGER check_donation_frequency BEFORE INSERT ON donation
FOR EACH ROW
BEGIN
  DECLARE last_donation_date DATE;
  
  -- Fetch the date of the last donation for the person
  SELECT MAX(d_date) INTO last_donation_date
  FROM donation
  WHERE p_id = NEW.p_id;
  
  -- Check if the last donation was within the last 90 days
  IF last_donation_date IS NOT NULL AND NEW.d_date <= DATE_ADD(last_donation_date, INTERVAL 90 DAY) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'This person cannot donate blood within the next 90 days.';
  END IF;
END;
//
DELIMITER ;
  
COMMIT;

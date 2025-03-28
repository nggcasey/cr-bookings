CREATE TABLE IF NOT EXISTS `cr_bookings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `entry_type` varchar(50) DEFAULT NULL,
  `business_id` varchar(50) NOT NULL,
  `staff_cid` varchar(50) NOT NULL,
  `booked_by` varchar(50) DEFAULT NULL,
  `start_time` bigint(20) unsigned NOT NULL,
  `end_time` bigint(20) NOT NULL,
  `appointment_type` text DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
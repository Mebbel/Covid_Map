USE rki_covid;

-- Create Users
-- Reference: https://www.digitalocean.com/community/tutorials/how-to-create-a-new-user-and-grant-permissions-in-mysql

-- Writing User - This one will be used for automated data update scripts
CREATE USER 'Write_User'@'localhost' IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON *.* TO 'Write_User'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Reading User - This user will be used for data analysis only. We do not want to alter the database by mistake
DROP USER 'Read_User'@'localhost';
FLUSH PRIVILEGES;
CREATE USER 'Read_User'@'localhost' IDENTIFIED BY '123456';
GRANT SELECT ON *.* to 'Read_User'@'localhost';

-- For RMySQL to work, we need to change the authentication method of the Read_User
ALTER USER 'Read_User'@'localhost' IDENTIFIED WITH mysql_native_password BY '123456';

-- Create Log Table for Downloads
DROP TABLE data_requests;
CREATE TABLE IF NOT EXISTS data_requests (
 ID_REQUEST INT AUTO_INCREMENT PRIMARY KEY,
 DATE_REQUEST VARCHAR(50),
 NAME_OF_REQUEST VARCHAR(100),
 NUMBER_OF_ROWS INT
);

-- Create Log Table for Errors in the process
CREATE TABLE IF NOT EXISTS log (
 ID_REQUEST INT,
 COMMENT TEXT
);

-- Create Table for Landkreis data
DROP TABLE rki_landkreis;
CREATE TABLE IF NOT EXISTS rki_landkreis (
	ID_REQUEST INT, 
	OBJECTID INT,
	ADE	INT,
	GF INT, 
	BSG	INT,
	RS	INT,
	AGS	INT, 
	SDV_RS BIGINT,
	GEN	VARCHAR(50),
	BEZ	VARCHAR(50),
	IBZ	INT,
	BEM	VARCHAR(25),
	NBD	VARCHAR(25),
	SN_L	INT,
	SN_R	INT,
	SN_K	INT,
	SN_V1	INT,
	SN_V2	INT,
	SN_G	INT,
	FK_S3	VARCHAR(25),
	NUTS	VARCHAR(25),
	RS_0	BIGINT,
	AGS_0	INT,
	WSK	VARCHAR(25),
	EWZ	INT,
	KFL	NUMERIC,
	DEBKG_ID	VARCHAR(25),
	death_rate	NUMERIC,
	cases	INT,
	deaths	INT,
	cases_per_100k	NUMERIC,
	cases_per_population	NUMERIC,
	BL	VARCHAR(50),
	BL_ID	INT,
	county	VARCHAR(50),
	last_update	VARCHAR(25),
	cases7_per_100k	NUMERIC,
	recovered	INT,
	EWZ_BL	INT,
	cases7_bl_per_100k	NUMERIC,
	cases7_bl	NUMERIC,
	death7_bl	NUMERIC,
	cases7_lk	NUMERIC,
	death7_lk	NUMERIC,
	cases7_per_100k_txt	NUMERIC,
	AdmUnitId	INT,
	SHAPE__Length	NUMERIC,
	SHAPE__Area	NUMERIC
)
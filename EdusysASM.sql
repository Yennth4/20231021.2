CREATE DATABASE EduSysASM
GO

USE EduSysASM
GO

/*
RelationShip Constraint Requirements -- Yêu cầu ràng buộc quan hệ
Update : CasCade ( Tất cả ) -- Đồng bộ hóa.
Delete : No Action. Ngoại trừ quan hệ KhoaHoc-HocVien Thì CasCade.
*/
-- Delete mà để là CasCade : Khi xóa 1 khóa học ( bảng cha )  thì tất cả khóa học đó ở bảng Học Viên ( con )  cx bị xóa luôn.
-- Delete mà để là No ACtion : Cấm xóa các chuyên đề đã có khóa học

IF OBJECT_ID( 'NhanVien'  , 'U') IS NOT NULL 
DROP TABLE  NhanVien ;
CREATE TABLE NhanVien /* Là một người thuộc phòng giáo vụ sử dụng phần mềm */
(
	MaNV	NVARCHAR(20) PRIMARY KEY , --Mã NV dùng để đăng nhập
	MatKhau NVARCHAR(50) not null	 , --Mật khẩu đăng nhập
	HoTen	NVARCHAR(50) not null	 , --Họ và tên
	VaiTro  BIT			 not null	DEFAULT 0  --ko nhập giá trị gì mặc định là 0 : Nhân Viên / 1 : Trường Phòng.
);
go


IF OBJECT_ID( 'ChuyenDe'  , 'U') IS NOT NULL 
DROP TABLE  ChuyenDe ;
CREATE TABLE ChuyenDe 
(
	MaCD			NCHAR(10)	  PRIMARY KEY	NOT NULL, --Mã chuyên đề
	TenCD			NVARCHAR(50)				NOT NULL, --Tên chuyên đề
	HocPhi			FLOAT						NOT NULL, --Học Phí
	ThoiLuong		INT							NOT NULL, -- Thời lượng 
	Hinh			NVARCHAR(100)				NOT NULL, --Hình ảnh 
	MoTa			NVARCHAR(230)				NOT NULL
);
GO


IF OBJECT_ID( 'KhoaHoc'  , 'U') IS NOT NULL 
DROP TABLE  KhoaHoc ;
CREATE TABLE KhoaHoc  
(
	MaKH		INT IDENTITY(1,1) PRIMARY KEY NOT NULL , --Mã khóa học
	MaCD		NCHAR(10)					  NOT NULL , --Mã Chuyên đề
	HocPhi		FLOAT						  NOT NULL , --Là học phí theo Chuyên Đề tại thời điểm tạo khóa học
	ThoiLuong	INT							  NOT NULL , --Thời lượng tính bằng giờ
	NgayKG		DATE						  NOT NULL , --ngày khai giảng
	GhiChu		NVARCHAR(250)				  NULL     ,
	MaNV		NVARCHAR(20)				  NOT NULL , --Mã Nhân viên nhập
	NgayTao     DATE						  DEFAULT GETDATE(), -- Ngày đăng ký của người học
	/*thiết lập khóa ngoại*/ 
	FOREIGN KEY ( MaCD ) REFERENCES ChuyenDe(MaCD) ON DELETE NO ACTION  ON UPDATE CASCADE , 
	FOREIGN KEY ( MaNV ) REFERENCES NhanVien(MaNV) ON DELETE NO ACTION  ON UPDATE CASCADE , 
);
GO	


IF OBJECT_ID( 'NguoiHoc'  , 'U') IS NOT NULL 
DROP TABLE  NguoiHoc ;
CREATE TABLE NguoiHoc /* Là người đăng ký tham gia học tập tại trung tâm */
(
	MaNH		NCHAR(7)	PRIMARY KEY		NOT NULL, --Mã người học
	HoTen		NVARCHAR(50)				NOT NULL, 
	GioiTinh	BIT							DEFAULT 1, --ko nhập gì mặc định là Nam
	NgaySinh	DATE						NOT NULL,
	Email		NVARCHAR(50)				NOT NULL,
	DienThoai	NVARCHAR(24)				NOT NULL,
	GhiChu		NVARCHAR(1000)				NULL, --
	MaNV		NVARCHAR(20)				NOT NULL, --Mã nhân viên nhập
	NgayDK		DATE						DEFAULT GETDATE(), --Ngày đăng ký của người học
	Hinh		NVARCHAR(255)				NOT NULL ,
	FOREIGN KEY ( MaNV ) REFERENCES NhanVien ( MaNV ) ON DELETE NO ACTION ON UPDATE CASCADE
);
GO


IF OBJECT_ID( 'HocVien'  , 'U') IS NOT NULL 
DROP TABLE  HocVien ;
CREATE TABLE HocVien 
(
	MaHV	INT			IDENTITY(1,1)  PRIMARY KEY	NOT NULL, -- Mã học viên ( số báo danh ) 
	MaKH	INT										NOT NULL,
	MaNH	NCHAR(7)								NOT NULL,
	Diem	FLOAT									DEFAULT -1 , 	--Điểm cuối môn		
	--Thiết lập khóa chính kết hợp ( composite primary key ) 
	--PRIMARY KEY ( MaKH , MaNH ) ,
	/*thiết lập khóa ngoại*/
	FOREIGN KEY ( MaNH ) REFERENCES NguoiHoc( MaNH ) ON DELETE NO ACTION ON UPDATE CASCADE , -- Khi xóa MaNH ở bảng chả ( NguoiHoc ) thì yêu cầu không có ở trong bảng con. Nếu ko sẽ lỗi. Khi Cập nhật MaNH ở bảng cha thì tất cả MaNH ở  bảng con ( HocVien ) cx sẽ cập nhật theo.
	FOREIGN KEY ( MaKH ) REFERENCES KhoaHoc ( MaKH ) ON DELETE CASCADE ON UPDATE NO ACTION   -- Khi xóa/cập nhật MaKH của khóa học ở bảng cha ( KhoaHoc ) thì tất cả MaKH ở bảng con  ( HocVien )  cx sẽ  bị xóa/cập nhật   THeo luôn
);
GO

/* Tạo Proc để thực hiện các chức năng nghiệp vụ ( trong giao diện Thống Kê ) 
1. Thống kê người học theo Năm
1. Tổng hợp bảng điểm của các khóa học
2. Thống Kê Doanh Thu + Số lượng người học : Từng chuyên đề theo năm
3. Điểm Chuyên Đề
4. Tổng hợp số lượng người học theo tháng. */

DROP PROCEDURE	 sp_ThongKeNguoiHocTheoNam
GO
CREATE OR ALTER PROC sp_ThongKeNguoiHocTheoNam
AS BEGIN 
		SELECT 
				YEAR	(NgayDK)	Năm, -- truy vấn từ cột NgayDK có kiểu dữ liệu là Year và có tên cột là Năm
				COUNT	(*)			Số_Lượng,--Đếm số bản ghi trong mỗi nhóm (NgayDK ) 
				MIN		(NgayDK)	Ngày_Đăng_Ký_Đầu_Tiên,--Chọn ngày đăng ký lớn nhất
				MAX		(NgayDK)	Ngày_Đăng_Ký_Cuối_Cùng--Chọn ngày đăng ký nhỏ nhất
		FROM NguoiHoc
		GROUP BY YEAR(NgayDK) --gộp theo năm.
END
GO
EXECUTE sp_ThongKeNguoiHocTheoNam
GO


DROP PROCEDURE	 sp_ThongKeBangDiem_TheoKhoaHoc
GO
CREATE  OR ALTER PROC sp_ThongKeBangDiem_TheoKhoaHoc ( @MaKH INT ) 
AS BEGIN
			SELECT 
						nh.MaNH		AS 'Mã Người Học'  ,
						nh.HoTen	AS 'Họ và tên' ,
						hv.Diem  	AS 'Điểm Người Học'

			FROM		NguoiHoc nh inner join HocVien hv 
			ON			nh.MaNH = hv.MaNH 
			WHERE		hv.MaKH = @MaKH
			ORDER BY 	hv.Diem  DESC -- descending order =  giảm dần
END
GO
EXECUTE sp_ThongKeBangDiem_TheoKhoaHoc 3;
GO


/*
Proc3. Bảng điểm theo chuyên đề 
Các thành phần : ChuyenDe-TongSoHV-DiemCaoNhat-DiemThapNhat-DiemTB
*/
DROP PROCEDURE	 sp_BangDiemTheoCD
GO
CREATE  OR ALTER PROC sp_BangDiemTheoCD
AS BEGIN
		 SELECT 
						cd.TenCD			AS 'Tên Chuyên Đề'		,
						COUNT( hv.MaHV )  	AS 'Tổng số người học' 	,
						MIN ( hv.Diem )		AS 'Điểm thấp  nhất'	,
						MAX ( hv.Diem )		AS 'Điểm cao nhất'		,
						AVG ( hv.Diem)		AS 'Điểm trung bình'	
		 FROM			ChuyenDe cd			inner join  KhoaHoc kh 
		 ON				cd.MaCD = kh.MaCD	inner join  HocVien hv
		 ON				kh.MaKH = hv.MaKH
		GROUP BY		cd.TenCD	--gộp theo tên chuyên đề
END
GO
EXECUTE sp_BangDiemTheoCD;
GO


/*
Proc4. Tổng hợp Doanh Thu từng chuyên đề theo năm.
Các thành phàn : ChuyenDe-SoKhoa-SoHV-DoanhThu-HPCaoNhat-HPThatNhat-HPTrungBinh
*/
DROP PROCEDURE	 sp_TongHopDoanhThu
GO
CREATE OR ALTER PROC sp_TongHopDoanhThu		 ( @YEAR INT ) 
AS BEGIN 
		   SELECT 
						cd.TenCD				AS 'Tên Chuyên Đề'	,
						COUNT( kh.MaKH )		AS 'Số Khóa Học'	,
						COUNT( hv.MaHV ) 		AS 'Số Học Viên'	,
						SUM  ( kh.HocPhi )		AS 'Doanh Thu theo từng chuyên đề',
						MAX	 ( kh.HocPhi )		AS	'HP Cao Nhất của khóa'	,
						MIN  ( kh.HocPhi )		AS	'HP Thấp Nhất của khóa'	, 
						AVG	 ( kh.HocPhi )		AS	'HP Trung Bình của tất cả các khóa'

		   FROM			ChuyenDe cd			inner join KhoaHoc kh 
		   ON			cd.MaCD	= kh.MaCD 	inner join  HocVien hv
		   ON		    kh.MaKH = hv.MaKH
		   WHERE		YEAR ( Kh.NgayKG ) 	 = 	   @YEAR
		   GROUP BY		cd.TenCD
END
GO
EXECUTE sp_TongHopDoanhThu 2023;
GO


INSERT INTO NhanVien 
(MaNV, MatKhau, HoTen, VaiTro)
VALUES 
( 'NV01' , 'manhhbph40818' , N'Hoàng Bá Mạnh' , 1 ),
( 'NV02' , 'yennthph31906' , N'Nguyễn Thị Hải Yến' , 1 ),
( 'NV03' , 'chienntph43534' , N'Nguyên Thế Chiến' , 0 )
GO


INSERT INTO ChuyenDe 
(MaCD, TenCD, HocPhi, ThoiLuong, Hinh, MoTa)
VALUES 
( 'CD001' , N'Lập Trình Java1'		, 8200000 , 660		, 'KissGio.jpg' , N'Khóa học về lập trình Java dành cho người mới bắt đầu' ),
( 'CD002' , N'githup'				, 5445200 , 360		, 'ADAV.jpg' , N'Học cách sử dụng Git và GitHub để quản lý mã nguồn' ),
( 'CD003' , N'HTML'					, 9544400 , 452		, 'ADBS.jpg' , N'Khóa học về HTML và CSS để xây dựng trang web' ),
( 'CD004' , N'PHP'					, 9800040 , 180		, 'ADTE.jpg' , N'Khóa học lập trình PHP cho người mới học lập trình' ),
( 'CD005' , N'Python'				, 8733000 , 690		, 'ADUI.jpg' , N'Nắm cơ bản về lập trình Python và ứng dụng thực tế' ),
( 'CD006', N'Lập Trình C++'			, 7500000, 420		, 'agile.png', N'Là một khóa học về lập trình C++.'),
( 'CD007', N'JavaScript'			, 6200000, 360		, 'Tym.jpg', N'Học lập trình JavaScript để xây dựng trang web động.'),
( 'CD008', N'Android Development'	, 8900000, 480		, 'ASNE.png', N'Xây dựng ứng dụng Android với Java hoặc Kotlin.'),
( 'CD009', N'Web Design'			,6900000, 300		, 'Attached.jpg', N'Tạo giao diện web đẹp và hiệu quả.'),
( 'CD010', N'Database Management'	, 8200000, 360		, 'AvaDefault.jpg', N'Quản lý cơ sở dữ liệu hiệu quả.'),
( 'CD011', N'Network Security'		, 9700000, 420		, 'CLCO.jpg', N'Bảo vệ mạng và dữ liệu.'),
( 'CD012', N'Digital Marketing'		, 5500000, 240		, 'DBAV.png', N'Tối ưu hóa chiến dịch tiếp thị số.'),
( 'CD013', N'Mobile App Design'		, 7200000, 360		, 'DBBS.png', N'Tạo giao diện ứng dụng di động thú vị.'),
( 'CD014', N'Python for Data Science', 7800000, 360		, 'github.png', N'Học Python để phân tích dữ liệu.'),
( 'CD015', N'Artificial Intelligence', 9000000, 480		, 'Hug.jpg', N'Nghiên cứu về trí tuệ nhân tạo và học máy.');	
GO


INSERT INTO NguoiHoc 
(MaNH, HoTen, GioiTinh, NgaySinh, Email, DienThoai, GhiChu, MaNV, NgayDK, Hinh)
VALUES 
( 'NH001' , N'Hoàng Bá Mạnh'	, 0 , '2000-03-14' , 'manhhbph40818@fpt.edu.vn' ,		'0984324209' , N'Xuất Xắc'		,'NV01' , '2023-05-15' , N'Please.jpg' ),
( 'NH002' , N'Nguyễn Thế Chiến' , 1 , '2001-02-20' , 'nguyenctph32432@fpt.edu.vn' ,	'0985584593'	 , N'Giỏi'			,'NV02' , '2020-07-20' , N'heineken_1.jpg' ),
( 'NH003' , N'Đinh Tiên Hoàng'	, 1 , '2003-05-30' , 'hoangdtph35524@fpt.edu.vn' ,	'0854984543'     , N'Xuất Xắc'		,'NV03' , '2022-08-23' , N'AvaDefault.jpg' ),
( 'NH004' , N'Triệu Tử Vân'		, 0 , '1999-03-14' , 'Vanttph122332@fpt.edu.vn' ,		'0886545353' , N'Trung Bình'	,'NV02' , '2021-02-19' , N'CLCO.jpg' ),
( 'NH005' , N'Lữ Bố'			, 0 , '1998-07-21' , 'Bolph08334@fpt.edu.vn' ,		'08854958354'	 , N'Khá'			,'NV01' , '2019-04-24' , N'java.png' ),
( 'NH006' , N'Điêu Thuyền'		, 1 , '1998-07-21' , 'Bolph08334@fpt.edu.vn' ,		'0123456789'	 , N'Khá'			,'NV01' , '2019-04-24' , N'java.png' ),
( 'NH007' , N'Tử Vân'			, 0 , '1998-07-21' , 'Bolph08334@fpt.edu.vn' ,		'0987654321'	 , N'Khá'			,'NV01'	   , '2019-04-24' , N'java.png' )
GO


INSERT INTO NguoiHoc 
(MaNH, HoTen, GioiTinh, NgaySinh, Email, DienThoai, GhiChu, MaNV, NgayDK, Hinh)
VALUES 
( 'NH008', N'Nguyễn Văn A', 0, '1995-03-14', 'nguyenvana@fpt.edu.vn', '0987654321', N'Thường', 'NV03', '2019-01-15', N'MOWE.png' ),
( 'NH009', N'Nguyễn Thị B', 1, '1997-07-20', 'nguyenthib@fpt.edu.vn', '0909090909', N'Tốt', 'NV01', '2019-03-20', N'noImage.png' ),
( 'NH010', N'Trần Văn C', 0	, '1998-05-30', 'tranvc@fpt.edu.vn', '0888888888', N'Khá', 'NV02', '2019-05-10', N'PHPP.png' ),
( 'NH011', N'Lê Thị D', 1, '1996-06-14', 'lethid@fpt.edu.vn', '0911111111', N'Xuất sắc', 'NV03', '2019-04-19', N'Please.jpg' ),
( 'NH012', N'Phạm Văn E', 0, '1997-10-21', 'phamve@fpt.edu.vn', '0898989898', N'Giỏi', 'NV01', '2019-02-24', N'PMAG.jpg' ),
( 'NH013', N'Hoàng Văn F', 0, '1999-02-15', 'hoangvf@fpt.edu.vn', '0999999999', N'Tốt', 'NV03', '2020-01-15', N'python.png' ),
( 'NH014', N'Nguyễn Thị G', 1, '1998-09-30', 'nguyentg@fpt.edu.vn', '0909090909', N'Khá', 'NV02', '2020-03-20', N'sqlserver.png' ),
( 'NH015', N'Trần Văn H', 0, '2000-05-25', 'tranvh@fpt.edu.vn', '0888888888', N'Xuất sắc', 'NV02', '2021-05-10', N'Subject.png' ),
( 'NH016', N'Lê Văn I', 0, '2002-01-14', 'lethi@fpt.edu.vn', '0911111111', N'Giỏi', 'NV01', '2021-04-19', N'TwoCat.jpg' ),
( 'NH017', N'Phạm Văn J', 1, '2003-03-21', 'phamvj@fpt.edu.vn', '0898989898', N'Tốt', 'NV03', '2021-02-24', N'VBPR.png' );
GO


INSERT INTO KhoaHoc	  
( MaCD,		HocPhi, ThoiLuong, NgayKG,		GhiChu,			 MaNV)
VALUES 
( 'CD001' , 8200000 , 660 , '2023-09-20' ,  N'Ghi chú 1' , 'NV01' ),
( 'CD001' , 820 , 660 , '2023-10-15' ,  N'Ghi chú 2' , 'NV01' ),
( 'CD002' , 55200 , 360 , '2023-11-05' ,  N'Ghi chú 3' , 'NV03' ),
( 'CD003' , 94400 , 452 , '2023-12-10' ,  N'Ghi chú 4' , 'NV02' ),
( 'CD004' , 940 , 180 , '2023-01-25' ,  N'Ghi chú 5' , 'NV01' ),
( 'CD005' , 1111111 , 360 , '2023-02-15' ,  N'Ghi chú 6' , 'NV03' ),
( 'CD006' , 22254343 , 452 , '2023-03-10' ,  N'Ghi chú 7' , 'NV02' ),
( 'CD007' , 33342334 , 180 , '2023-04-25' ,  N'Ghi chú 8' , 'NV01' ),
( 'CD008' , 4444534 , 660 , '2023-05-20' ,  N'Ghi chú 9' , 'NV01' ),
( 'CD009' , 55545453 , 360 , '2023-06-05' ,  N'Ghi chú 10' , 'NV03' );
GO


INSERT INTO KhoaHoc 
(MaCD, HocPhi, ThoiLuong, NgayKG, GhiChu, MaNV, NgayTao)
VALUES 
( 'CD001' , 8200000 , 660 , '2023-09-20' , N'Ghi chú 1' , 'NV01', DATEADD(day, -30, '2023-09-20')),
( 'CD001' , 820 , 660 , '2023-10-15' , N'Ghi chú 2' , 'NV01', DATEADD(day, -21, '2023-10-15')),
( 'CD002' , 55200 , 360 , '2023-11-05' , N'Ghi chú 3' , 'NV03', DATEADD(day, -13, '2023-11-05')),
( 'CD003' , 94400 , 452 , '2023-12-10' , N'Ghi chú 4' , 'NV02', DATEADD(day, -202, '2023-12-10')),
( 'CD004' , 940 , 180 , '2023-01-25' , N'Ghi chú 5' , 'NV01', DATEADD(day, -203, '2023-01-25')),
( 'CD005' , 1111111 , 360 , '2023-02-15' , N'Ghi chú 6' , 'NV03', DATEADD(day, -530, '2023-02-15')),
( 'CD006' , 22254343 , 452 , '2023-03-10' , N'Ghi chú 7' , 'NV02', DATEADD(day, -330, '2023-03-10')),
( 'CD007' , 33342334 , 180 , '2023-04-25' , N'Ghi chú 8' , 'NV01', DATEADD(day, -130, '2023-04-25')),
( 'CD008' , 4444534 , 660 , '2023-05-20' , N'Ghi chú 9' , 'NV01', DATEADD(day, -30, '2023-05-20')),
( 'CD009' , 55545453 , 360 , '2023-06-05' , N'Ghi chú 10' , 'NV03', DATEADD(day, -30, '2023-06-05'));
GO


INSERT INTO HocVien 
(MaKH,  MaNH,  Diem)
VALUES 
( 3 ,  'NH001'	,  9.7 ), -- NH001 học 2 khóa học 1 và 2
( 8 ,  'NH001'	,  10 ), 
( 3 ,  'NH002'	,  9.3 ), -- NH002 học khóa học 3
( 4,   'NH003'	,  2.4 ), -- NH003 học khóa học 3
( 5,   'NH003'	, 7.6),
( 6,   'NH004'	, 8.0),
( 7,   'NH004'	, 8.7),
( 8,   'NH005'	, 9.2),
( 9,   'NH006'	, 5.3),
(10,   'NH007'	, 7.8);
GO

SELECT * FROM NhanVien
SELECT * FROM ChuyenDe
SELECT * FROM NguoiHoc
SELECT * FROM KhoaHoc
SELECT * FROM HocVien
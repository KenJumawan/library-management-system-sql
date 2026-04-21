--Library FOR MAIN FOCUS
--COPY ARCHITECTURE FORM INCLASS EXAMPLE, SIMPLY CHANGE DATA WITHIN
CREATE TABLE MEMBER (
  MEM_ID      NUMERIC(10,0) PRIMARY KEY,
  MEM_FNAME   VARCHAR(20) NOT NULL   ,
  MEM_LNAME   VARCHAR(20) NOT NULL   ,
);

CREATE TABLE BOOK (
  BOOK_NUM   NUMERIC(10,0) PRIMARY KEY,
  BOOK_TITLE VARCHAR(120) NOT NULL  ,
  BOOK_YEAR  NUMERIC(4)               ,
  BOOK_COST  NUMERIC(8,2)             ,
  BOOK_SUBJECT VARCHAR(120)         
);

CREATE TABLE AUTHOR (
  AU_ID        NUMERIC(7,0) PRIMARY KEY,
  AU_FNAME     VARCHAR(30) NOT NULL  ,
  AU_LNAME     VARCHAR(30) NOT NULL  ,
  AU_BIRTHYEAR NUMERIC(4)
);

CREATE TABLE WRITES (
  BOOK_NUM  NUMERIC(10),
  AU_ID     NUMERIC(7),
  CONSTRAINT WRITES_BOOK_AU_PK PRIMARY KEY (BOOK_NUM, AU_ID),
  CONSTRAINT WRITES_BOOK_NUM_FK FOREIGN KEY(BOOK_NUM) REFERENCES BOOK(BOOK_NUM),
  CONSTRAINT WRITES_AU_ID_FK FOREIGN KEY(AU_ID) REFERENCES AUTHOR(AU_ID)
);

CREATE TABLE CHECKOUT (
  CHECK_NUM         NUMERIC(15) PRIMARY KEY,
  BOOK_NUM          NUMERIC(10),
  MEM_ID            NUMERIC(10),
  CHECK_OUT_DATE    DATE,
  CHECK_DUE_DATE    DATE,
  CHECK_IN_DATE     DATE,
  FOREIGN KEY (BOOK_NUM) REFERENCES BOOK(BOOK_NUM),
  FOREIGN KEY (MEM_ID) REFERENCES MEMBER(MEM_ID)
);


--function- finding late fee (returns output)adds up total fees for all books overdue that person has
create or alter function getOverdueCharge(@memNum int) returns decimal(8,2)
as begin
declare @charge decimal(8,2), @due date, @diff int;
declare check_cursor cursor for 
select CHECK_DUE_DATE from checkout c join book b on c.BOOK_NUM = b.BOOK_NUM where c.MEM_ID = @memNum 
and CHECK_IN_DATE is null and CHECK_DUE_DATE < getDate();
set @charge = 0;
open check_cursor
fetch next from check_cursor into @due

while @@FETCH_STATUS = 0
begin
set @diff = datediff(week, @due, getDate());
set @charge = @charge + (convert(int,@diff) * 3.99);

fetch next from check_cursor into @due
end
close check_cursor;
deallocate check_cursor;

return @charge
end
go


--cursor - cursor with each book in the library and wether or not it is checked out
DECLARE @num int, @title varchar(100), @subject varchar(25), @status varchar(15); 
DECLARE book_cursor CURSOR FOR   
select BOOK_NUM, BOOK_TITLE, BOOK_SUBJECT,
case
	when BOOK_NUM in (select b.BOOK_NUM 
	FROM book b join checkout c on c.BOOK_NUM = b.BOOK_NUM 
	where c.CHECK_IN_DATE is null) then 'Checked Out'
	when BOOK_NUM not in (select b.BOOK_NUM 
	FROM book b join checkout c on c.BOOK_NUM = b.BOOK_NUM 
	where c.CHECK_IN_DATE is null) then 'Checked In'
end
FROM book;
  
OPEN book_cursor    
FETCH NEXT FROM book_cursor INTO @num, @title, @subject, @status

while @@FETCH_STATUS = 0
BEGIN
PRINT(CONVERT(varchar(10), @num) + ' ' +  @title + ' ' + @subject + ' ' + @status);

FETCH NEXT FROM book_cursor INTO @num, @title, @subject, @status
END

CLOSE book_cursor;  
DEALLOCATE book_cursor;


--trigger - update checkout rows when inserted to include due date one week after check out
--ideally, this would work by updating check out date to be getdate() 
--and due date to be getDate() + 7 days.  However, this would create problems with creating the table
--as if all insert statements are created on the same day, they will all have the same check out and due
--dates.
(create or alter trigger Add_Due_Date on checkout
for insert
as begin
update checkout set check_out_date = getDate();
update checkout set check_due_date = dateadd(day, 7, CHECK_OUT_DATE)
where CHECK_NUM in (select distinct CHECK_NUM from inserted); 
end)

create or alter trigger Add_Due_Date on checkout
for insert
as begin
update checkout set check_due_date = dateadd(day, 7, CHECK_OUT_DATE)
where CHECK_NUM in (select distinct CHECK_NUM from inserted) 
end

--procedures - procedure to view all books one individual currently has checked out  param is mem_code

create or alter procedure getMemberCheckout @mem_num int
as begin
select b.BOOK_NUM, b.BOOK_TITLE, c.CHECK_OUT_DATE, c.CHECK_DUE_DATE, c.CHECK_IN_DATE
from member m join checkout c on m.MEM_ID = c.MEM_ID join book b on b.BOOK_NUM = c.BOOK_NUM
where c.MEM_ID = @mem_num and check_in_date is null;
end
go

--procedure for finding all overdue books   no param  uses getDate()

create or alter procedure getOverdue
as begin
select CHECK_NUM, m.MEM_ID, b.BOOK_NUM, MEM_FNAME, MEM_LNAME, BOOK_TITLE
from checkout c join member m on c.MEM_ID = m.MEM_ID join book b on b.BOOK_NUM = c.BOOK_NUM
where CHECK_DUE_DATE < getdate() and CHECK_IN_DATE is null;
end
go

create database employee_leave_management;
use employee_leave_management;

-- 1. database schema

create table departments (
    department_id int primary key,
    department_name varchar(50) not null unique
);

create table employees (employee_id int primary key, department_id int not null,employee_name varchar(100) not null,
    phone varchar(15),email varchar(120) unique,constraint fk_employee_department foreign key (department_id)
    references departments(department_id)
);

create table managers (
    manager_id int primary key,
    manager_name varchar(100) not null
);

create table leave_types (
    leave_type_id int primary key,
    leave_type_name varchar(50) not null unique
);

create table leave_requests (
    leave_id int primary key,employee_id int not null,manager_id int not null,leave_type_id int not null,start_date date not null,
    end_date date not null,total_days int not null, status enum('pending', 'approved', 'rejected', 'cancelled') not null default 'pending',
    reason varchar(255),constraint fk_leave_employee foreign key (employee_id) references employees(employee_id), constraint fk_leave_manager
	foreign key (manager_id) references managers(manager_id),constraint fk_leave_type foreign key (leave_type_id) references leave_types(leave_type_id),
    constraint chk_leave_dates check (end_date >= start_date), constraint chk_total_days check (total_days > 0)
);

-- leave balance tracking

create table leave_balances (
    employee_id int not null, leave_type_id int not null, allocated_days int not null default 20, remaining_days int not null default 20,
    primary key (employee_id, leave_type_id), foreign key (employee_id) references employees(employee_id), 
    foreign key (leave_type_id) references leave_types(leave_type_id), check (allocated_days >= 0),
    check (remaining_days >= 0),check (remaining_days <= allocated_days)
);

-- 2. sample data

insert into departments values
(1, 'hr'),
(2, 'it'),
(3, 'finance'),
(4, 'sales'),
(5, 'administration');

insert into managers values
(1, 'ramesh'),
(2, 'priya'),
(3, 'kiran'),
(4, 'sneha'),
(5, 'arun');

insert into leave_types values
(1, 'casual leave'),
(2, 'sick leave'),
(3, 'earned leave'),
(4, 'maternity leave'),
(5, 'unpaid leave');

insert into employees values
(101, 1, 'aarav', '9876500001', 'aarav@mail.com'),
(102, 2, 'bhavya', '9876500002', 'bhavya@mail.com'),
(103, 3, 'charan', '9876500003', 'charan@mail.com'),
(104, 4, 'divya', '9876500004', 'divya@mail.com'),
(105, 5, 'esha', '9876500005', 'esha@mail.com'),
(106, 2, 'farhan', '9876500006', 'farhan@mail.com'),
(107, 1, 'gopi', '9876500007', 'gopi@mail.com'),
(108, 3, 'hari', '9876500008', 'hari@mail.com'),
(109, 4, 'isha', '9876500009', 'isha@mail.com'),
(110, 5, 'john', '9876500010', 'john@mail.com');

insert into leave_requests values
(1001, 101, 1, 1, '2026-07-01', '2026-07-03', 3, 'approved', 'personal work'),
(1002, 102, 2, 2, '2026-07-02', '2026-07-04', 3, 'pending', 'fever'),
(1003, 103, 3, 3, '2026-07-05', '2026-07-06', 2, 'approved', 'vacation'),
(1004, 104, 4, 1, '2026-07-07', '2026-07-08', 2, 'rejected', 'family function'),
(1005, 105, 5, 5, '2026-07-10', '2026-07-12', 3, 'approved', 'personal'),
(1006, 106, 2, 2, '2026-07-11', '2026-07-11', 1, 'pending', 'medical'),
(1007, 107, 1, 1, '2026-07-13', '2026-07-15', 3, 'approved', 'travel'),
(1008, 108, 3, 3, '2026-07-16', '2026-07-20', 5, 'approved', 'vacation'),
(1009, 109, 4, 2, '2026-07-18', '2026-07-19', 2, 'rejected', 'sick'),
(1010, 110, 5, 1, '2026-07-21', '2026-07-22', 2, 'pending', 'personal');

-- initialize leave balances

insert into leave_balances
    (employee_id, leave_type_id, allocated_days, remaining_days)
select e.employee_id,
       lt.leave_type_id,
       case when lt.leave_type_id = 5 then 0 else 20 end,
       case when lt.leave_type_id = 5 then 0 else 20 end
from employees e
cross join leave_types lt;

-- deduct approved paid leave days

update leave_balances b
join (
    select employee_id,
           leave_type_id,
           sum(total_days) as days_used
    from leave_requests
    where status = 'approved'
      and leave_type_id <> 5
    group by employee_id, leave_type_id
) u
on u.employee_id = b.employee_id
and u.leave_type_id = b.leave_type_id
set b.remaining_days = greatest(0, b.remaining_days - u.days_used);

-- q1. list all leave requests
select * from leave_requests;

-- q2. display leave requests with employee names
select lr.leave_id,
       e.employee_name,
       lr.start_date,
       lr.end_date,
       lr.total_days,
       lr.status,
       lr.reason
from leave_requests lr
join employees e on e.employee_id = lr.employee_id;

-- q3. show approved leave requests
select *
from leave_requests
where status = 'approved';

-- q4. show pending leave requests
select *
from leave_requests
where status = 'pending';

-- q5. employees currently on leave
select distinct e.employee_id,
       e.employee_name,
       lr.start_date,
       lr.end_date
from employees e
join leave_requests lr on lr.employee_id = e.employee_id
where lr.status = 'approved'
  and curdate() between lr.start_date and lr.end_date;

-- q6. count leave requests department-wise
select d.department_id,
       d.department_name,
       count(lr.leave_id) as request_count
from departments d
left join employees e on e.department_id = d.department_id
left join leave_requests lr on lr.employee_id = e.employee_id
group by d.department_id, d.department_name
order by request_count desc, d.department_name;

-- q7. count leave requests by status
select status, count(*) as request_count
from leave_requests
group by status;

-- q8. average requested leave days by department
select d.department_name,
       round(avg(lr.total_days), 2) as average_leave_days
from departments d
join employees e on e.department_id = d.department_id
join leave_requests lr on lr.employee_id = e.employee_id
group by d.department_id, d.department_name;

-- q9. employee(s) with the maximum total approved leave days
select e.employee_id,
       e.employee_name,
       sum(lr.total_days) as approved_leave_days
from employees e
join leave_requests lr on lr.employee_id = e.employee_id
where lr.status = 'approved'
group by e.employee_id, e.employee_name
having sum(lr.total_days) = (
    select max(employee_days)
    from (
        select sum(total_days) as employee_days
        from leave_requests
        where status = 'approved'
        group by employee_id
    ) as totals
);

-- q10. department(s) with the maximum number of leave requests
select d.department_name,
       count(lr.leave_id) as request_count
from departments d
join employees e on e.department_id = d.department_id
join leave_requests lr on lr.employee_id = e.employee_id
group by d.department_id, d.department_name
having count(lr.leave_id) = (
    select max(dept_count)
    from (
        select count(lr2.leave_id) as dept_count
        from departments d2
        join employees e2 on e2.department_id = d2.department_id
        join leave_requests lr2 on lr2.employee_id = e2.employee_id
        group by d2.department_id
    ) as counts_by_department
);

-- q11. employees with more than 2 leave requests
select e.employee_id,
       e.employee_name,
       count(lr.leave_id) as request_count
from employees e
join leave_requests lr on lr.employee_id = e.employee_id
group by e.employee_id, e.employee_name
having count(lr.leave_id) > 2;

-- q12. employees who never applied for leave
select e.employee_id, e.employee_name
from employees e
left join leave_requests lr on lr.employee_id = e.employee_id
where lr.leave_id is null;

-- q13. latest 5 leave requests
select *
from leave_requests
order by start_date desc, leave_id desc
limit 5;

-- q14. leave requests whose start date is in the last 30 days
select *
from leave_requests
where start_date >= curdate() - interval 30 day
  and start_date <= curdate()
order by start_date desc;

-- q15. employee names in uppercase and lowercase
select employee_name,
       upper(employee_name) as uppercase_name,
       lower(employee_name) as lowercase_name
from employees;

-- q16. first 3 characters of employee names
select employee_name,
       left(employee_name, 3) as first_three_characters
from employees;

-- q17. calculate leave duration from dates
select leave_id,
       start_date,
       end_date,
       datediff(end_date, start_date) + 1 as calculated_days,
       total_days as stored_days
from leave_requests;

-- q18. generate leave reference
select leave_id,
       concat('el-', leave_id) as leave_reference
from leave_requests;

-- q19. leave types used more than 5 times
select lt.leave_type_name,
       count(lr.leave_id) as times_used
from leave_types lt
join leave_requests lr on lr.leave_type_id = lt.leave_type_id
group by lt.leave_type_id, lt.leave_type_name
having count(lr.leave_id) > 5;

-- q20. manager-wise approved leave count
select m.manager_id,
       m.manager_name,
       count(lr.leave_id) as approved_count
from managers m
left join leave_requests lr
    on lr.manager_id = m.manager_id
   and lr.status = 'approved'
group by m.manager_id, m.manager_name
order by approved_count desc;

-- q21. requests exceeding their department's average duration
select e.employee_id,
       e.employee_name,
       lr.leave_id,
       lr.total_days,
       dept_avg.average_days
from employees e
join leave_requests lr on lr.employee_id = e.employee_id
join (
    select e2.department_id,
           avg(lr2.total_days) as average_days
    from employees e2
    join leave_requests lr2 on lr2.employee_id = e2.employee_id
    group by e2.department_id
) as dept_avg on dept_avg.department_id = e.department_id
where lr.total_days > dept_avg.average_days;

-- q22. monthly leave statistics
select date_format(start_date, '%Y-%m') as leave_month,
       count(*) as request_count,
       sum(total_days) as requested_days,
       sum(status = 'approved') as approved_requests,
       sum(status = 'pending') as pending_requests,
       sum(status = 'rejected') as rejected_requests
from leave_requests
group by date_format(start_date, '%Y-%m')
order by leave_month;

-- q23. longest approved leave taken
select lr.leave_id,
       e.employee_name,
       lr.start_date,
       lr.end_date,
       lr.total_days
from leave_requests lr
join employees e on e.employee_id = lr.employee_id
where lr.status = 'approved'
  and lr.total_days = (
      select max(total_days)
      from leave_requests
      where status = 'approved'
  );

-- q24. remaining leave balance
select e.employee_id,
       e.employee_name,
       lt.leave_type_name,
       b.allocated_days,
       b.remaining_days,
       b.allocated_days - b.remaining_days as used_days
from leave_balances b
join employees e on e.employee_id = b.employee_id
join leave_types lt on lt.leave_type_id = b.leave_type_id
order by e.employee_id, lt.leave_type_id;

-- q25. open leave requests
select *
from leave_requests
where status = 'pending';

-- q26. rejected leave requests
select *
from leave_requests
where status = 'rejected';

-- 4. views (q27-q28)

create view approved_leaves as
select lr.leave_id,
       e.employee_name,
       lt.leave_type_name,
       lr.start_date,
       lr.end_date,
       lr.total_days,
       lr.status,
       lr.reason
from leave_requests lr
join employees e on e.employee_id = lr.employee_id
join leave_types lt on lt.leave_type_id = lr.leave_type_id
where lr.status = 'approved';

create view pending_leaves as
select lr.leave_id,
       e.employee_name,
       lt.leave_type_name,
       lr.start_date,
       lr.end_date,
       lr.total_days,
       lr.status,
       lr.reason
from leave_requests lr
join employees e on e.employee_id = lr.employee_id
join leave_types lt on lt.leave_type_id = lr.leave_type_id
where lr.status = 'pending';

-- examples
select * from approved_leaves;
select * from pending_leaves;

-- 5. transactions and procedures (q29-q30)

delimiter //

create procedure approve_leave(in p_leave_id int)
begin
    declare v_employee_id int;
    declare v_leave_type_id int;
    declare v_days int;
    declare v_status varchar(20);
    declare v_remaining int;

    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    select employee_id, leave_type_id, total_days, status
    into v_employee_id, v_leave_type_id, v_days, v_status
    from leave_requests
    where leave_id = p_leave_id
    for update;

    if v_status <> 'pending' then
        signal sqlstate '45000'
            set message_text = 'only pending requests can be approved';
    end if;

    if v_leave_type_id <> 5 then
        select remaining_days
        into v_remaining
        from leave_balances
        where employee_id = v_employee_id
          and leave_type_id = v_leave_type_id
        for update;

        if v_remaining < v_days then
            signal sqlstate '45000'
                set message_text = 'insufficient leave balance';
        end if;

        update leave_balances
        set remaining_days = remaining_days - v_days
        where employee_id = v_employee_id
          and leave_type_id = v_leave_type_id;
    end if;

    update leave_requests
    set status = 'approved'
    where leave_id = p_leave_id;

    commit;
end //

create procedure cancel_leave(in p_leave_id int)
begin
    declare v_employee_id int;
    declare v_leave_type_id int;
    declare v_days int;
    declare v_status varchar(20);

    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    select employee_id, leave_type_id, total_days, status
    into v_employee_id, v_leave_type_id, v_days, v_status
    from leave_requests
    where leave_id = p_leave_id
    for update;

    if v_status <> 'approved' then
        signal sqlstate '45000'
            set message_text = 'only approved requests can be cancelled';
    end if;

    if v_leave_type_id <> 5 then
        update leave_balances
        set remaining_days = least(allocated_days, remaining_days + v_days)
        where employee_id = v_employee_id
          and leave_type_id = v_leave_type_id;
    end if;

    update leave_requests
    set status = 'cancelled'
    where leave_id = p_leave_id;

    commit;
end //

delimiter ;

-- usage examples
-- call approve_leave(1002);
-- call cancel_leave(1001);

-- 6. stored procedures (q31-q32)

delimiter //

create procedure get_manager_leave_requests(in p_manager_id int)
begin
    select e.employee_name,
           lt.leave_type_name,
           lr.start_date,
           lr.end_date,
           lr.status
    from leave_requests lr
    join employees e on e.employee_id = lr.employee_id
    join leave_types lt on lt.leave_type_id = lr.leave_type_id
    where lr.manager_id = p_manager_id
    order by lr.start_date desc;
end //

create procedure get_employee_approved_leave_days(in p_employee_id int)
begin
    select p_employee_id as employee_id,
           coalesce(sum(total_days), 0) as total_approved_leave_days
    from leave_requests
    where employee_id = p_employee_id
      and status = 'approved';
end //

delimiter ;

-- usage examples
-- call get_manager_leave_requests(2);
-- call get_employee_approved_leave_days(101);

-- 7. audit tables and triggers (q33-q34)

create table leave_request_log (
    log_id bigint auto_increment primary key,
    leave_id int not null,
    employee_id int not null,
    leave_type_id int not null,
    status varchar(20) not null,
    created_at datetime not null default current_timestamp
);

create table leave_status_history (
    history_id bigint auto_increment primary key,
    leave_id int not null,
    employee_id int not null,
    old_status varchar(20) not null,
    new_status varchar(20) not null,
    changed_at datetime not null default current_timestamp
);

delimiter //

create trigger trg_leave_request_insert
after insert on leave_requests
for each row
begin
    insert into leave_request_log
        (leave_id, employee_id, leave_type_id, status)
    values
        (new.leave_id, new.employee_id, new.leave_type_id, new.status);
end //

create trigger trg_leave_status_update
after update on leave_requests
for each row
begin
    if old.status <> new.status then
        insert into leave_status_history
            (leave_id, employee_id, old_status, new_status)
        values
            (new.leave_id, new.employee_id, old.status, new.status);
    end if;
end //

delimiter ;

-- verification examples

insert into leave_requests
    (leave_id, employee_id, manager_id, leave_type_id,
     start_date, end_date, total_days, status, reason)
values
    (1011, 101, 1, 1, '2026-08-01', '2026-08-03',
     3, 'pending', 'testing trigger log');

select * from leave_request_log;

call approve_leave(1011);

select * from leave_status_history;
select * from approved_leaves;
select * from pending_leaves;

show procedure status where db = 'employee_leave_management';
show triggers;